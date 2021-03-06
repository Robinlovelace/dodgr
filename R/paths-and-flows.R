#' dodgr_paths
#'
#' Calculate lists of pair-wise shortest paths between points.
#'
#' @param graph \code{data.frame} or equivalent object representing the network
#' graph (see Details)
#' @param from Vector or matrix of points **from** which route distances are to
#' be calculated (see Details)
#' @param to Vector or matrix of points **to** which route distances are to be
#' calculated (see Details)
#' @param vertices If \code{TRUE}, return lists of lists of vertices for each
#' path, otherwise return corresponding lists of edge numbers from \code{graph}.
#' @param wt_profile Name of weighting profile for street networks (one of foot,
#' horse, wheelchair, bicycle, moped, motorcycle, motorcar, goods, hgv, psv).
#' @param heap Type of heap to use in priority queue. Options include
#' Fibonacci Heap (default; \code{FHeap}), Binary Heap (\code{BHeap}),
#' \code{Radix}, Trinomial Heap (\code{TriHeap}), Extended Trinomial Heap
#' (\code{TriHeapExt}, and 2-3 Heap (\code{Heap23}).
#' @param quiet If \code{FALSE}, display progress messages on screen.
#' @return List of list of paths tracing all connections between nodes such that
#' if \code{x <- dodgr_paths (graph, from, to)}, then the path between
#' \code{from[i]} and \code{to[j]} is \code{x [[i]] [[j]]}.
#'
#' @note \code{graph} must minimally contain four columns of \code{from},
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
#' \code{to} are specified, pairwise distances are calculated between all nodes
#' in \code{graph}.
#'
#' @export
#' @examples
#' graph <- weight_streetnet (hampi)
#' from <- sample (graph$from_id, size = 100)
#' to <- sample (graph$to_id, size = 50)
#' dp <- dodgr_paths (graph, from = from, to = to)
#' # dp is a list with 100 items, and each of those 100 items has 30 items, each
#' # of which is a single path listing all vertiex IDs as taken from \code{graph}.
dodgr_paths <- function (graph, from, to, vertices = TRUE,
                         wt_profile = "bicycle", heap = 'BHeap', quiet = TRUE)
{
    if (missing (graph) & (!missing (from) | !missing (to)))
        graph <- graph_from_pts (from, to, expand = 0.1,
                                 wt_profile = wt_profile, quiet = quiet)

    hps <- get_heap (heap, graph)
    heap <- hps$heap
    graph <- hps$graph

    gr_cols <- dodgr_graph_cols (graph)
    # cols are (edge_id, from, to, d, w, component, xfr, yfr, xto, yto)
    vert_map <- make_vert_map (graph, gr_cols)

    index_id <- get_index_id_cols (graph, gr_cols, vert_map, from)
    from_index <- index_id$index - 1 # 0-based
    from_id <- index_id$id
    index_id <- get_index_id_cols (graph, gr_cols, vert_map, to)
    to_index <- index_id$index - 1 # 0-based
    to_id <- index_id$id

    graph <- convert_graph (graph, gr_cols)

    if (!quiet)
        message ("Calculating shortest paths ... ", appendLF = FALSE)
    paths <- rcpp_get_paths (graph, vert_map, from_index, to_index, heap)

    # convert 1-based indices back into vertex IDs:
    paths <- lapply (paths, function (i)
                     lapply (i, function (j)
                             vert_map$vert [j] ))

    # name path lists
    for (i in seq (from_index))
        names (paths [[i]]) <- paste0 (from_id [1], "-", to_id)
    names (paths) <- from_id

    if (!vertices)
    {
        # convert vertex IDs to corresponding sequences of edge numbers
        graph_verts <- paste0 ("f", graph$from, "t", graph$to)

        paths <- lapply (paths, function (i)
                         lapply (i, function (j)
                                 if (length (j) > 0)
                                 {
                                     indx <- 2:length (j)
                                     pij <- paste0 ("f", j [indx - 1],
                                                    "t", j [indx])
                                     match (pij, graph_verts)
                                 } ))
    }

    return (paths)
}


nodes_arg_to_pts <- function (nodes, graph)
{
    if (!is.matrix (nodes))
        nodes <- as.matrix (nodes)
    if (ncol (nodes) == 2)
    {
        verts <- dodgr_vertices (graph)
        nodes <- verts$id [match_pts_to_graph (verts, nodes)]
    }
    return (nodes)
}


# keep from and to routing points in contracted graph
contract_graph_with_pts <- function (graph, from, to)
{
    pts <- NULL
    if (!missing (from))
        pts <- c (pts, from)
    if (!missing (to))
        pts <- c (pts, to)
    graph_full <- graph
    graph <- dodgr_contract_graph (graph, unique (pts))
    graph$graph_full <- graph_full
    return (graph)
}

# map contracted flows back onto full graph
uncontract_graph <- function (graph, edge_map, graph_full)
{
    indx_to_full <- match (edge_map$edge_old, graph_full$edge_id)
    indx_to_contr <- match (edge_map$edge_new, graph$edge_id)
    # edge_map only has the contracted edges; flows from the original
    # non-contracted edges also need to be inserted
    edges <- graph$edge_id [which (!graph$edge_id %in% edge_map$edge_new)]
    indx_to_full <- c (indx_to_full, match (edges, graph_full$edge_id))
    indx_to_contr <- c (indx_to_contr, match (edges, graph$edge_id))
    graph_full$flow <- 0
    graph_full$flow [indx_to_full] <- graph$flow [indx_to_contr]

    return (graph_full)
}

#' dodgr_flows
#'
#' Aggregate flows throughout a network based on an input matrix of flows
#' between all pairs of \code{from} and \code{to} points.
#'
#' @param graph \code{data.frame} or equivalent object representing the network
#' graph (see Details)
#' @param from Vector or matrix of points **from** which route distances are to
#' be calculated (see Details)
#' @param to Vector or matrix of points **to** which route distances are to be
#' calculated (see Details)
#' @param flows Matrix of flows with \code{nrow(flows)==length(from)} and
#' \code{ncol(flows)==length(to)}.
#' @param wt_profile Name of weighting profile for street networks (one of foot,
#' horse, wheelchair, bicycle, moped, motorcycle, motorcar, goods, hgv, psv).
#' @param contract If \code{TRUE}, calculate flows on contracted graph before
#' mapping them back on to the original full graph (recommended as this will
#' generally be much faster).
#' @param aggregate_all If \code{TRUE}, flows are aggregated from each origin
#' (\code{from} point) to \strong{ALL} other points according to an exponential
#' decay from points of origin.
#' @param k Width coefficient of exponential decay for \code{aggregate_all =
#' TRUE}, with distance decay defined as \code{exp(-d/k)}. If value of
#' \code{k<0} is given, a standard logistic polynomial will be used.
#' @param heap Type of heap to use in priority queue. Options include
#' Fibonacci Heap (default; \code{FHeap}), Binary Heap (\code{BHeap}),
#' \code{Radix}, Trinomial Heap (\code{TriHeap}), Extended Trinomial Heap
#' (\code{TriHeapExt}, and 2-3 Heap (\code{Heap23}).
#' @param quiet If \code{FALSE}, display progress messages on screen.
#' @return Modified version of graph with additonal \code{flow} column added.
#'
#' @note If \code{aggregate_all = TRUE}, then \code{to} points are ignored, and
#' only the first column of \code{flows} is used.
#'
#' @export
#' @examples
#' graph <- weight_streetnet (hampi)
#' from <- sample (graph$from_id, size = 10)
#' to <- sample (graph$to_id, size = 5)
#' to <- to [!to %in% from]
#' flows <- matrix (10 * runif (length (from) * length (to)),
#'                  nrow = length (from))
#' graph <- dodgr_flows (graph, from = from, to = to, flows = flows)
#' # graph then has an additonal 'flows` column of aggregate flows along all
#' # edges. These flows are directed, and can be aggregated to equivalent
#' # undirected flows on an equivalent undirected graph with:
#' graph_undir <- merge_directed_flows (graph)
#' # This graph will only include those edges having non-zero flows, and so:
#' nrow (graph); nrow (graph_undir) # the latter is much smaller
dodgr_flows <- function (graph, from, to, flows, wt_profile = "bicycle",
                         contract = FALSE, aggregate_all = FALSE, k = 2,
                         heap = 'BHeap', quiet = TRUE)
{
    if (missing (graph) & (!missing (from) | !missing (to)))
        graph <- graph_from_pts (from, to, expand = 0.1,
                                 wt_profile = wt_profile, quiet = quiet)

    if ("flow" %in% names (graph))
        warning ("graph already has a 'flow' column; ",
                  "this will be overwritten")

    if (any (is.na (flows))) {
        flows [is.na (flows)] <- 0
    }
    hps <- get_heap (heap, graph)
    heap <- hps$heap
    graph <- hps$graph

    # change from and to just to check conformity
    if (!missing (from))
        from <- nodes_arg_to_pts (from, graph)
    if (!missing (to))
        to <- nodes_arg_to_pts (to, graph)

    if (contract)
    {
        graph <- contract_graph_with_pts (graph, from, to)
        graph_full <- graph$graph_full
        edge_map <- graph$edge_map
        graph <- graph$graph
    }

    gr_cols <- dodgr_graph_cols (graph)
    vert_map <- make_vert_map (graph, gr_cols)

    index_id <- get_index_id_cols (graph, gr_cols, vert_map, from)
    from_index <- index_id$index - 1 # 0-based
    #from_id <- index_id$id
    index_id <- get_index_id_cols (graph, gr_cols, vert_map, to)
    to_index <- index_id$index - 1 # 0-based
    #to_id <- index_id$id

    if (!is.matrix (flows))
        flows <- as.matrix (flows)

    graph2 <- convert_graph (graph, gr_cols)

    if (!quiet)
        message ("\nAggregating flows ... ", appendLF = FALSE)

    if (!aggregate_all)
        graph$flow <- rcpp_flows_aggregate (graph2, vert_map,
                                            from_index, to_index,
                                            flows, heap)
    else
        graph$flow <- rcpp_flows_disperse (graph2, vert_map,
                                           from_index, k,
                                           flows, heap)

    if (contract) # map contracted flows back onto full graph
        graph <- uncontract_graph (graph, edge_map, graph_full)

    return (graph)
}

#' merge_directed_flows
#'
#' The \code{dodgr_flows} function returns a column of aggregated flows directed
#' along each edge of a graph, so the aggregated flow from vertex A to vertex B
#' will not necessarily equal that from B to A, and the total flow in both
#' directions will be the sum of flow from A to B plus that from B to A. This
#' function converts a directed graph to undirected form through reducing all
#' pairs of directed edges to a single edge, and aggregating flows from both
#' directions.
#'
#' @param graph A graph containing a \code{flow} column as returned from
#' \code{dodgr_flows}
#' @return An equivalent graph in which all directed edges have been reduced to
#' single, undirected edges, and all directed flows aggregated to undirected
#' flows.
#' @export
#' @examples
#' graph <- weight_streetnet (hampi)
#' from <- sample (graph$from_id, size = 10)
#' to <- sample (graph$to_id, size = 5)
#' to <- to [!to %in% from]
#' flows <- matrix (10 * runif (length (from) * length (to)),
#'                  nrow = length (from))
#' graph <- dodgr_flows (graph, from = from, to = to, flows = flows)
#' # graph then has an additonal 'flows` column of aggregate flows along all
#' # edges. These flows are directed, and can be aggregated to equivalent
#' # undirected flows on an equivalent undirected graph with:
#' graph_undir <- merge_directed_flows (graph)
#' # This graph will only include those edges having non-zero flows, and so:
#' nrow (graph); nrow (graph_undir) # the latter is much smaller
merge_directed_flows <- function (graph)
{
    if (!"flow" %in% names (graph))
        stop ("graph does not have any flows to merge")

    gr_cols <- dodgr_graph_cols (graph)
    graph2 <- convert_graph (graph, gr_cols)
    graph2$flow <- graph$flow

    flows <- rcpp_merge_flows (graph2)

    indx <- which (flows > 0)
    graph <- graph [indx, , drop = FALSE] #nolint
    graph$flow <- flows [indx]
    return (graph)
}

#' dodgr_spatial_interaction
#'
#' Fit a single-constrained exponential spatial interaction model to a vector of
#' location densities. 
#'
#' @param graph \code{data.frame} or equivalent object representing the network
#' graph (see Details)
#' @param nodes Vector of points at which spatial interactions are to be
#' calculated (see Details)
#' @param dens Vector of corresponding densities used to calculate spatial
#' interactions
#' @param k Width coefficient of exponential spatial interaction model.
#' @param heap Type of heap to use in priority queue. Options include
#' Fibonacci Heap (default; \code{FHeap}), Binary Heap (\code{BHeap}),
#' \code{Radix}, Trinomial Heap (\code{TriHeap}), Extended Trinomial Heap
#' (\code{TriHeapExt}, and 2-3 Heap (\code{Heap23}).
#' @param contract If \code{TRUE}, calculate flows on contracted graph before
#' mapping them back on to the original full graph (recommended as this will
#' generally be much faster).
#' @param quiet If \code{FALSE}, display progress messages on screen.
#' @return Matrix of same number of rows and columns as length of \code{nodes}
#' and \code{dens}, with rows containing the spatial interactions between each
#' node and all others.
#'
#' @export
dodgr_spatial_interaction <- function (graph, nodes = NULL, dens = NULL, k = 2,
                                       contract = TRUE, heap = 'BHeap',
                                       quiet = TRUE)
{
    if (any (is.na (dens))) {
        dens [is.na (dens)] <- 0
    }
    hps <- get_heap (heap, graph)
    heap <- hps$heap
    graph <- hps$graph

    if (length (nodes) != length (dens))
        stop ("nodes and dens must have same length")
    if (!(is.vector (nodes) & is.vector (dens)))
        stop ("nodes and dens must both be vectors")
    if (length (nodes) < 2)
        stop ("spatial interactions can only be calculated between vectors ",
              "of length > 1")

    if (!missing (nodes))
        nodes <- nodes_arg_to_pts (nodes, graph)

    if (contract)
        graph <- contract_graph_with_pts (graph, nodes)$graph

    gr_cols <- dodgr_graph_cols (graph)
    vert_map <- make_vert_map (graph, gr_cols)

    index_id <- get_index_id_cols (graph, gr_cols, vert_map, nodes)
    node_index <- index_id$index - 1 # 0-based

    graph2 <- convert_graph (graph, gr_cols)

    if (!quiet)
        message ("\nCalculating spatial interaction matrix ... ",
                 appendLF = FALSE)

    rcpp_spatial_interaction (graph2, vert_map, node_index, k, dens, heap)
}
