#' dodgr.
#'
#' Distances on dual-weighted directed graphs using priority-queue shortest
#' paths. Weighted directed graphs have weights from A to B which may differ
#' from those from B to A. Dual-weighted directed graphs have two sets of such
#' weights. A canonical example is a street network to be used for routing in
#' which routes are calculated by weighting distances according to the type of
#' way and mode of transport, yet lengths of routes must be calculated from
#' direct distances.
#'
#' @section The Main Function:
#' \itemize{
#' \item \code{\link{dodgr_dists}}: Calculate pair-wise distances between
#' specified pairs of points in a graph.
#' }
#'
#' @section Functions to Obtain Graphs:
#' \itemize{
#' \item \code{\link{dodgr_streetnet}}: Extract a street network in Simple
#' Features (\code{sf}) form.
#' \item \code{\link{weight_streetnet}}: Convert an \code{sf}-formatted street
#' network to a \code{dodgr} graph through applying specified weights to all
#' edges.
#' }
#'
#' @section Functions to Modify Graphs:
#' \itemize{
#' \item \code{\link{dodgr_components}}: Number all graph edges according to
#' their presence in distinct connected components.
#' \item \code{\link{dodgr_convert_graph}}: Convert a graph of arbitrary form
#' into a standardised, minimal form for submission to \code{dodgr} routines.
#' \item \code{\link{dodgr_contract_graph}}: Contract a graph by removing
#' redundant edges.
#' }
#'
#' @section Miscellaneous Functions:
#' \itemize{
#' \item \code{\link{dodgr_sample}}: Randomly sample a graph, returning a single
#' connected component of a defined number of vertices.
#' \item \code{\link{dodgr_vertices}}: Extract all vertices of a graph.
#' \item \code{\link{compare_heaps}}: Compare the performance of different
#' priority queue heap structures for a given type of graph.
#' }
#'
#' @name dodgr
#' @docType package
#' @importFrom igraph distances E make_directed_graph
#' @importFrom magrittr %>%
#' @importFrom methods is
#' @importFrom osmdata add_osm_feature getbb opq osmdata_sf
#' @importFrom rbenchmark benchmark
#' @importFrom sp bbox point.in.polygon
#' @importFrom Rcpp evalCpp
#' @useDynLib dodgr, .registration = TRUE
NULL

#' weighting_profiles
#'
#' Collection of weighting profiles used to adjust the routing process to
#' different means of transport. Original data taken from the Routino project.
#'
#' @name weighting_profiles
#' @docType data
#' @keywords datasets
#' @format \code{data.frame} with profile names, means of transport and
#' weights.
#' @references \url{https://www.routino.org/xml/routino-profiles.xml}
NULL

#' hampi
#'
#' A sample street network from the township of Hampi, Karnataka, India.
#'
#' @name hampi
#' @docType data
#' @keywords datasets
#' @format A Simple Features \code{sf} \code{data.frame} containing the street
#' network of Hampi.
#'
#' @note Can be re-created with the following command, which also removes 
#' extraneous columns to reduce size:
#' @examples \dontrun{
#' hampi <- dodgr_streetnet("hampi india")
#' cols <- c ("osm_id", "highway", "oneway", "geometry")
#' hampi <- hampi [, which (names (hampi) %in% cols)]
#' }
#' # this 'sf data.frame' can be converted to a 'dodgr' network with
#' net <- weight_streetnet (hampi, wt_profile = 'foot')
NULL

#' os_roads_bristol
#'
#' A sample street network for Bristol, U.K., from the Ordnance Survey.
#'
#' @name os_roads_bristol
#' @docType data
#' @keywords datasets
#' @format A Simple Features \code{sf} \code{data.frame} representing
#' motorways in Bristol, UK.
#'
#' @note Input data downloaded from 
#' \url{https://www.ordnancesurvey.co.uk/opendatadownload/products.html}.
#' To download the data from that page click on the tick box next to
#' 'OS Open Roads', scroll to the bottom, click 'Continue' and complete
#' the form on the subsequent page.
#' This dataset is open access and can be used under the
#' \href{https://www.ordnancesurvey.co.uk/business-and-government/licensing/using-creating-data-with-os-products/os-opendata.html}{Open Government License} and must be cited as follows:
#' Contains OS data © Crown copyright and database right (2017)
#'  
#' @examples \dontrun{
#' library(sf)
#' library(dplyr)
#' os_roads <- sf::read_sf("~/data/ST_RoadLink.shp") # data must be unzipped here
#' u <- "https://opendata.arcgis.com/datasets/686603e943f948acaa13fb5d2b0f1275_4.kml"
#' lads <- sf::read_sf(u)
#' mapview::mapview(lads)
#' bristol_pol <- dplyr::filter(lads, grepl("Bristol", lad16nm))
#' os_roads <- st_transform(os_roads, st_crs(lads))
#' os_roads_bristol <- os_roads[bristol_pol, ] %>% 
#'   dplyr::filter(class == "Motorway" & roadNumber != "M32") %>% 
#'   st_zm(drop = TRUE)
#' mapview::mapview(os_roads_bristol)
#' }
#' # Converting this 'sf data.frame' to a 'dodgr' network requires manual
#' # specification of weighting profile:
#' colnm <- "formOfWay"
#' wts <- c (0.1, 0.2, 0.8, 1)
#' names (wts) <- unique (os_roads_bristol [[colnm]])
#' net <- weight_streetnet (os_roads_bristol, wt_profile = wts,
#'                          type_col = colnm, id_col = "identifier")
NULL
