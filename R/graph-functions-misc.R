# Miscellaneous **non-exported** graph functions

#' is_graph_spatial
#'
#' Is the graph spatial or not?
#' @param graph A \code{data.frame} of edges
#' @return \code{TRUE} is \code{graph} is spatial, otherwise \code{FALSE}
#' @noRd
is_graph_spatial <- function (graph)
{
    ncol (graph) > 4 &
        (any (grepl ("x", names (graph) [find_fr_col (graph)],
                     ignore.case = TRUE)) |
         any (grepl ("y", names (graph) [find_to_col (graph)],
                     ignore.case = TRUE)) |
         any (grepl ("lon", names (graph), ignore.case = TRUE)) |
         any (grepl ("lat", names (graph), ignore.case = TRUE)))
}

#' Get graph columns containing the from vertex
#' @noRd
find_fr_col <- function (graph)
{
    which (grepl ("fr", names (graph), ignore.case = TRUE) |
           grepl ("sta", names (graph), ignore.case = TRUE))
}

#' Get graph columns containing the to vertex
#' @noRd
find_to_col <- function (graph)
{
    which (grepl ("to", names (graph), ignore.case = TRUE) |
           grepl ("sto", names (graph), ignore.case = TRUE))
}

#' Get single graph column containing the ID of the from vertex
#' @noRd
find_fr_id_col <- function (graph)
{
    fr_col <- find_fr_col (graph)
    if (is_graph_spatial (graph))
    {
        frx_col <- find_xy_col (graph, fr_col, x = TRUE)
        fry_col <- find_xy_col (graph, fr_col, x = FALSE)
        fr_col <- fr_col [which (!fr_col %in%
                                 c (frx_col, fry_col))]
    }
    if (length (fr_col) != 1)
        stop ("Unable to determine column with ID of from vertices")
    return (fr_col)
}

#' Get single graph column containing the ID of the to vertex
#' @noRd
find_to_id_col <- function (graph)
{
    to_col <- find_to_col (graph)
    if (is_graph_spatial (graph))
    {
        tox_col <- find_xy_col (graph, to_col, x = TRUE)
        toy_col <- find_xy_col (graph, to_col, x = FALSE)
        to_col <- to_col [which (!to_col %in%
                                 c (tox_col, toy_col))]
    }
    if (length (to_col) != 1)
        stop ("Unable to determine column with ID of from vertices")
    return (to_col)
}

#' find_xy_col
#'
#' Find columns in graph containing lon and lat coordinates
#' @param indx columns of graph containing either to or from values, so xy
#' columns can be returned separately for each case
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

#' find_spatial_cols
#'
#' @return \code{fr_col} and \code{to_col} as vectors of 2 values of \code{x}
#' then \code{y} coordinates
#'
#' @noRd
find_spatial_cols <- function (graph)
{

    fr_col <- find_fr_col (graph)
    to_col <- find_to_col (graph)

    if (length (fr_col) < 2 | length (to_col) < 2)
        stop (paste0 ("Graph appears to be spatial yet unable to ",
                      "extract coordinates."))

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
        xy_fr_id <- paste0 (graph [, fr_col [1]],
                            graph [, fr_col [2]])
        xy_to_id <- paste0 (graph [, to_col [1]],
                            graph [, to_col [2]])
    }

    list (fr_col = fr_col,
          to_col = to_col,
          xy_id = data.frame (xy_fr_id = xy_fr_id,
                              xy_to_id = xy_to_id,
                              stringsAsFactors = FALSE))
}

find_d_col <- function (graph)
{
    d_col <- which (tolower (substring (names (graph), 1, 1)) == "d" &
                    tolower (substring (names (graph), 2, 2)) != "w" &
                    tolower (substring (names (graph), 2, 2)) != "_")
    if (length (d_col) != 1)
        stop ("Unable to determine distance column in graph")
    return (d_col)
}

find_w_col <- function (graph)
{
    w_col <- which (tolower (substring (names (graph), 1, 1)) == "w" |
                    tolower (substring (names (graph), 1, 2)) == "dw" |
                    tolower (substring (names (graph), 1, 3)) == "d_w")
    if (length (w_col) > 1)
        stop ("Unable to determine weight column in graph")
    return (w_col)
}

#' find_xy_col_simple
#'
#' Find the x and y cols of a simple data.frame of verts of xy points (used only
#' in match_pts_to_graph).
#' @param dfr Either the result of \code{dodgr_vertices}, or a \code{data.frame}
#' or equivalent structure (matrix, \pkg{tibble}) of spatial points.
#' @return Vector of two values of location of x and y columns
#' @noRd
find_xy_col_simple <- function (dfr)
{
    nms <- names (dfr)
    if (is.null (nms))
        nms <- colnames (dfr)

    if (!is.null (nms))
    {
        ix <- which (grepl ("x", nms, ignore.case = TRUE) |
                     grepl ("lon", nms, ignore.case = TRUE))
        iy <- which (grepl ("y", nms, ignore.case = TRUE) |
                     grepl ("lat", nms, ignore.case = TRUE))
    } else
    {
        # verts always has cols, so this can only happen for dfr = xy
        message ("xy has no named columns; assuming order is x then y")
        ix <- 1
        iy <- 2
    }
    c (ix, iy)
}

#' match_pts_to_graph
#'
#' Match spatial points to a spatial graph which contains vertex coordindates
#'
#' @param verts A \code{data.frame} of vertices obtained from
#' \code{dodgr_vertices(graph)}.
#' @param xy coordinates of points to be matched to the vertices, either as
#' matrix or \pkg{sf}-formatted \code{data.frame}.
#'
#' @return A vector index into verts
#' @export
#' @examples
#' net <- weight_streetnet (hampi, wt_profile = "foot")
#' verts <- dodgr_vertices (net)
#' # Then generate some random points to match to graph
#' npts <- 10
#' xy <- data.frame (
#'                   x = min (verts$x) + runif (npts) * diff (range (verts$x)),
#'                   y = min (verts$y) + runif (npts) * diff (range (verts$y))
#'                   )
#' pts <- match_pts_to_graph (verts, xy)
#' pts # an index into verts
#' pts <- verts$id [pts]
#' pts # names of those vertices
match_pts_to_graph <- function (verts, xy)
{
    if (!(is.matrix (xy) | is.data.frame (xy)))
        stop ("xy must be a matrix or data.frame")
    if (!is (xy, "sf"))
        if (ncol (xy) != 2)
            stop ("xy must have only two columns")

    xyi <- find_xy_col_simple (verts)
    verts <- data.frame (x = verts [, xyi [1]], y = verts [, xyi [2]])
    if (is (xy, "tbl"))
        xy <- data.frame (xy)
    if (is (xy, "sf"))
    {
        if (!"geometry" %in% names (xy))
            stop ("xy has no sf geometry column")
        if (!is (xy$geometry, "sfc_POINT"))
            stop ("xy$geometry must be a collection of sfc_POINT objects")
        xy <- unlist (lapply (xy$geometry, as.numeric)) %>%
            matrix (nrow = 2) %>% t ()
        xy <- data.frame (x = xy [, 1], y = xy [, 2])
    } else
    {
        xyi <- find_xy_col_simple (xy)
        xy <- data.frame (x = xy [, xyi [1]], y = xy [, xyi [2]])
    }

    # rcpp_points_index is 0-indexed, so ...
    #rcpp_points_index (verts, xy) + 1
    rcpp_points_index_par (verts, xy) + 1
}
