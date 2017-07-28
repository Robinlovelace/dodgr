#' dodgr_dists
#'
#' @param graph \code{data.frame} or equivalent object representing the network
#' graph (see Details)
#' @param from Vector or matrix of points **from** which route distances are to
#' be calculated (see Details)
#' @param to Vector or matrix of points **to** which route distances are to be
#' calculated (see Details)
#' @param heap Type of heap to use in priority queue. Options include
#' Fibonacci Heap (default; \code{FHeap}), Binary Heap (\code{BHeap}),
#' \code{Radix}, Trinomial Heap (\code{TriHeap}), Extended Trinomial Heap
#' (\code{TriHeapExt}, and 2-3 Heap (\code{Heap23}).
#' @return square matrix of distances between nodes
#'
#' @note \code{graph} must minimially contain four columns of \code{from},
#' \code{to}, \code{dist}. If an additional column named \code{weight} or
#' \code{wt} is present, shortest paths are calculated according to values
#' specified in that column; otherwise according to \code{dist} values. Either
#' way, final distances between \code{from} and \code{to} points are calculated
#' according to values of \code{dist}. That is, paths between any pair of points
#' will be calculated according to the minimal total sum of \code{weight}
#' values (if present), while reported distances will be total sums of
#' \code{dist} values.
#'
#' The \code{from} and \code{to} columns of \code{graph} may be either single
#' columns of numeric or character values specifying the numbers or names of
#' graph vertices, or combinations to two columns specifying geographical
#' (longitude and latitude) coordinates. In the latter case, almost any sensible
#' combination of names will be accepted (for example, \code{fromx, fromy},
#' \code{from_x, from_y}, or \code{fr_lat, fr_lon}.)
#'
#' \code{from} and \code{to} values can be either two-column matrices of
#' equivalent of longitude and latitude coordinates, or else single columns
#' precisely matching node numbers or names given in \code{graph$from} or
#' \code{graph$to}. If \code{to} is missing, pairwise distances are calculated
#' between all points specified in \code{from}. If neither \code{from} nor
#' \code{to} are specified, pairwise distances are calcualted between all nodes
#' in \code{graph}.
#'
#' @export
dodgr_dists <- function(graph, from, to, heap = 'BHeap')
{
    heaps <- c ("FHeap", "BHeap", "Radix", "TriHeap", "TriHeapExt", "Heap23")
    heap <- match.arg (arg = heap, choices = heaps)
    if (heap == "Radix")
    {
        dfr <- min (abs (c (graph$d %% 1, graph$d %% 1 - 1)))
        if (dfr > 1e-6)
        {
            message (paste0 ("RadixHeap can only be implemented for ",
                             "integer weights;\nall weights will now be ",
                             "rounded"))
            graph$d <- round (graph$d)
            graph$d_weighted <- round (graph$d_weighted)
        }
    }

    graph <- convert_graph (graph)
    xy <- graph$xy
    graph <- graph$graph
    vert_map <- make_vert_map (graph)

    if (!missing (from))
    {
        if (ncol (from) >= 2)
        {
            ix <- which (grepl ("x", names (from), ignore.case = TRUE) |
                         grepl ("lon", names (from), ignore.case = TRUE))
            iy <- which (grepl ("y", names (from), ignore.case = TRUE) |
                         grepl ("lat", names (from), ignore.case = TRUE))
            if (length (ix) != 1 | length (iy) != 1)
                stop (paste0 ("Unable to determine geographical ",
                              "coordinates in from"))

            if (is.null (xy))
                stop (paste0 ("graph has no geographical coordinates ",
                              "against which to match from"))

            # Then match from to graph using shorest Euclidean distances
            # TODO: Implement full Haversine?
            ngr <- nrow (graph)
            nfr <- nrow (from)
            frx_mat <- matrix (from [, ix], nrow = nfr, ncol = ngr)
            fry_mat <- matrix (from [, iy], nrow = nfr, ncol = ngr)
            grx_mat <- t (matrix (xy$x, nrow = ngr, ncol = nfr))
            gry_mat <- t (matrix (xy$y, nrow = ngr, ncol = nfr))
            dxy_mat <- (frx_mat - grx_mat) ^ 2 + (fry_mat - gry_mat) ^ 2

            indx <- apply (dxy_mat, 1, which.min)
        }
    }

    d <- rcpp_get_sp (graph, heap)

    if (max (d) > 1e30) # float max ~ 1e38
        d [d == max (d)] <- NA

    return (d)
}

#' convert_graph
#'
#' Convert graph to standard 4-column format for submission to C++ routines
#' @noRd
convert_graph <- function (graph)
{
    d_col <- which (tolower (substring (names (graph), 1, 1)) == "d" &
                    tolower (substring (names (graph), 2, 2)) != "w" &
                    tolower (substring (names (graph), 2, 2)) != "_")
    w_col <- which (tolower (substring (names (graph), 1, 1)) == "w" |
                    tolower (substring (names (graph), 1, 2)) == "dw" |
                    tolower (substring (names (graph), 1, 3)) == "d_w")
    if (length (d_col) > 1 | length (w_col) > 1)
        stop ("Unable to determine distance and/or weight columns in graph")
    else if (length (d_col) != 1)
        stop ("Unable to determine distance column in graph")

    fr_col <- which (grepl ("fr", names (graph), ignore.case = TRUE))
    to_col <- which (grepl ("to", names (graph), ignore.case = TRUE))

    xy <- NULL
    if (ncol (graph) > 4)
    {
        if (any (grepl ("x", names (graph), ignore.case = TRUE)) |
            any (grepl ("y", names (graph), ignore.case = TRUE)) |
            any (grepl ("lon", names (graph), ignore.case = TRUE)) |
            any (grepl ("lat", names (graph), ignore.case = TRUE)))
        {
            if (length (fr_col) != length (to_col))
                stop (paste0 ("from and to columns in graph appear ",
                              "to have different strutures"))
            else if (length (fr_col) >= 2 & length (to_col) >= 2)
            {
                if (length (fr_col) == 3)
                {
                    frx_col <- find_xy_col (graph, fr_col, x = TRUE)
                    fry_col <- find_xy_col (graph, fr_col, x = FALSE)
                    frid_col <- fr_col [which (!fr_col %in%
                                               c (frx_col, fry_col))]
                    fr_col <- c (frx_col, fry_col)
                    xy_fr_id <- graph [, frid_col]
                    if (!is.character (xy_fr_id))
                        xy_fr_id <- paste0 (xy_fr_id)

                    tox_col <- find_xy_col (graph, to_col, x = TRUE)
                    toy_col <- find_xy_col (graph, to_col, x = FALSE)
                    toid_col <- to_col [which (!to_col %in%
                                               c (tox_col, toy_col))]
                    to_col <- c (tox_col, toy_col)
                    xy_to_id <- graph [, toid_col]
                    if (!is.character (xy_to_id))
                        xy_to_id <- paste0 (xy_to_id)
                } else # len == 2, so must be only x-y
                {
                    xy_fr_id <- paste0 (xy_fr [, fr_col [1]],
                                        xy_fr [, fr_col [2]])
                    xy_to_id <- paste0 (xy_to [, to_col [1]],
                                        xy_to [, to_col [2]])
                }

                xy_fr <- graph [, fr_col]
                xy_to <- graph [, to_col]
                if (!(all (apply (xy_fr, 2, is.numeric)) |
                      all (apply (xy_to, 2, is.numeric))))
                    stop (paste0 ("graph appears to have non-numeric ",
                                  "longitudes and latitudes"))
                xy <- cbind (graph [, fr_col], graph [, to_col])

                # then replace 4 xy from/to cols with 2 from/to cols
                graph <- data.frame ("from" = xy_fr_id,
                                     "to" = xy_to_id,
                                     "d" = graph [, d_col],
                                     "w" = graph [, w_col],
                                     stringsAsFactors = FALSE)
            }
        } else
        {
            if (length (fr_col) != 1 & length (to_col) != 1)
                stop ("Unable to determine from and to columns in graph")
            
            graph <- data.frame ("from" = graph [, fr_col],
                                 "to" = graph [, to_col],
                                 "d" = graph [, d_col],
                                 "w" = graph [, w_col],
                                 stringsAsFactors = FALSE)
        }
    } else if (ncol (graph == 4))
    {
        graph <- data.frame ("from" = graph [, fr_col],
                             "to" = graph [, to_col],
                             "d" = graph [, d_col],
                             "w" = graph [, w_col],
                             stringsAsFactors = FALSE)

    }

    if (!is.character (graph$from))
        graph$from <- paste0 (graph$from)
    if (!is.character (graph$to))
        graph$to <- paste0 (graph$to)

    return (list (graph = graph, xy = xy))
}

#' find_xy_col
#' @noRd
find_xy_col <- function (graph, indx, x = TRUE)
{
    if (x)
        coli <- which (grepl ("x", names (graph) [indx], ignore.case = TRUE) |
                       grepl ("lon", names (graph) [indx], ignore.case = TRUE))
    else
        coli <- which (grepl ("y", names (graph) [indx], ignore.case = TRUE) |
                       grepl ("lat", names (graph) [indx], ignore.case = TRUE))

    indx [coli]
}

#' make_vert_map
#'
#' Map unique vertex names to sequential numbers in matrix
#' @noRd
make_vert_map <- function (graph)
{
    verts <- unique (c (graph$from, graph$to))
    data.frame (vert = verts, id = seq (verts), stringsAsFactors = FALSE)
}