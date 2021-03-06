## ------------------------------------------------------------------------
#' Return spline-smoothed expression plots over pseudotime.
#'
#' @export
time_series = function( dge, gene, colour = "eday", main = NULL, x = "pseudotime", col = Thanksgiving_colors, add_points = T ){
  atae( length( gene ), 1 )
  if( is.null(main)){ main = paste0( "Expression by ", x)}
    
  # Sanitize input -- `aes_string` chokes on a genes with hyphens (Nkx2-1)
  rownames( dge@data ) = make.names( rownames( dge@data ) )
  rownames( dge@raw.data ) = make.names( rownames( dge@raw.data ) )
  rownames( dge@scale.data ) = make.names( rownames( dge@scale.data ) )
  gene = make.names( gene )
  
  
  my_df = FetchDataZeroPad( dge, vars.all = c( x, gene, colour ) ) 
  my_df = my_df[order(my_df[[x]]), ]
  atat( all( sapply( my_df, FUN = is.numeric)))
  s = mgcv:::s
  my_df$smoothed_vals = mgcv::gam( family = mgcv::nb(), 
                                   formula = as.formula(paste0( gene, " ~ s(", x, ")" )),
                                   data = my_df ) %>% predict(type = "response")
  p = ggplot( my_df ) + ggtitle( main ) + 
    geom_smooth( aes_string( x=x, y=gene ), 
                 formula = y ~ s(x),
                 colour = "black",
                 method = mgcv::gam, 
                 method.args = list( family = mgcv::nb() )) 
  if( add_points ){
    p = p + geom_point( aes_string( x=x, y=gene, colour = colour ) ) 
  } 
  p = p + coord_cartesian(ylim=c(0,2*max(my_df$smoothed_vals) + 0.01)) 
  p = p + scale_y_continuous(labels = function(x) sprintf("%4.1f", x) )
  p = p + ggtitle( gene )
  if( !is.null( col ) ){ p = p + scale_color_gradientn( colours = col ) }
  return( p )
}

#' Save plots from `times_series`.
#'
#' @param types For an explanation of the "types" param, see ?tnse_colored .
#' 
#' @export
time_series_save = function( dge, 
                             results_path, 
                             gene,
                             x = "pseudotime",
                             types = c("pdf", "pdf_no_leg"), 
                             width = 8,
                             height = 6,
                             colour = "eday",
                             ... ){
  types = tolower(types)
  # Sanitize input -- `aes_string` chokes on a genes with hyphens (Nkx2-1)
  rownames( dge@data ) = make.names( rownames( dge@data ) )
  rownames( dge@raw.data ) = make.names( rownames( dge@raw.data ) )
  rownames( dge@scale.data ) = make.names( rownames( dge@scale.data ) )
  gene = make.names( gene )
  
  
  p = time_series( dge, gene, colour = colour, x = x, ... )
  results_path = file.path( results_path, "time_series" )
  dir.create.nice( results_path )
  if( "pdf" %in% types ){
    ggsave( filename = file.path( results_path, paste0( gene, ".pdf") ),
          plot = p,
          width = width, height = height)
  } 
  if( any( c("pdf_noleg", "pdf_no_leg") %in% types ) ){
    ggsave( filename = file.path( results_path, paste0( gene, "_no_leg.pdf") ),
            plot = p + theme(legend.position="none"),
            width = width, height = height)
  }
  if( any( c( "png_pdf_split", "pdf_png_split" ) %in% types ) ){
    # PNG no axis tick labels, no axis labels, and no legend
    ggsave( filename = file.path( results_path, paste0( gene, ".png") ),
            plot = p + 
              theme(legend.position="none") +
              theme(axis.text.x  = element_blank(), 
                    axis.text.y  = element_blank()) + 
              xlab("") + ylab("") + ggtitle(""),
            width = width, height = height)
    
    # ==== PDF with no points ====
    # Copy plot and remove points
    p_no_pts = p
    p_no_pts$layers = p_no_pts$layers[1]
    # Add four points to get the right y axis and color legend
    p1 = which.max( FetchDataZeroPad( dge, gene )[[1]] )[1]
    p2 = which.min( FetchDataZeroPad( dge, gene )[[1]] )[1]
    p3 = which.max( FetchDataZeroPad( dge, colour )[[1]] )[1]
    p4 = which.min( FetchDataZeroPad( dge, colour )[[1]] )[1]
    p_no_pts = p_no_pts + geom_point( data = FetchDataZeroPad( dge, c( x, colour, gene ) )[c( p1, p2, p3, p4 ) , , drop = F],
                                      aes_string( x = x, y = gene, colour = colour ) )
    ggsave( filename = file.path( results_path, paste0( gene, "_few_pts.pdf") ),
            plot = p_no_pts ,
            width = width, height = height)
  } 
  if( "pdf_no_cells" %in% types ){
    p_no_pts = p
    p_no_pts$layers = p_no_pts$layers[1]
    ggsave( filename = file.path( results_path, paste0( gene, "_no_pts.pdf") ),
            plot = p_no_pts ,
            width = width, height = height)
  }
}

#' Make tSNE plots (or PCA, or Monocle; it's customizable)
#' 
#' @param dge Seurat object
#' @param colour Variable to fetch and plot. Length-1 character. "plain_grey" returns a dark grey plot.
#' @param subset_id Vector of subsets to include on the plot. Cells not included will still be included via
#' geom_blank so as to preserve the scale of the plot.
#' @param axes Variables to fetch for use on X and Y axes. Defaults to tSNE embedding.
#' @param fix_coords Force the plot to be square? Defaults to T, because a rotated or reflected version of 
#' the tSNE embedding should convey the exact same relationships. 
#' @param alpha Transparency. Number between 0 and 1. 
#' @param cols.use Colorscale. Character vector, hexadecimal or e.g. c("khaki1", "red"). 
#' For discrete data fetched for "colour", should be named with the variable's levels.
#' @param use_rank Transform expression level to ranks before plotting?
#' @param overplot_adjust Bin points within hexagons. Nice for Monocle embeddings. 
#' 
#' @export
#'
custom_feature_plot = function(dge, colour = NULL, subset_id = NULL, axes = c("tSNE_1", "tSNE_2"), 
                               fix_coords = T, show_axes = F,
                               alpha = 1, cols.use = c("khaki1", "red"), use_rank = F, overplot_adjust = F ){
  # Remove NA's. They otherwise cause a nasty bug that I haven't pinned down.
  dge %<>% FillNA
  
  # Sanitize input -- `aes_string` may choke on genes with hyphens (e.g. Nkx2-1)
  rownames( dge@data ) = make.names( rownames( dge@data ) )
  rownames( dge@raw.data ) = make.names( rownames( dge@raw.data ) )
  rownames( dge@scale.data ) = make.names( rownames( dge@scale.data ) )
  colour = make.names( colour )
  axes = make.names( axes )
  my_df = FetchDataZeroPad(dge, vars.all = c(axes, colour, "ident" ), use.raw = F)
  
  # # Omit some cells if user wants to omit them
  # # but keep the plotting window the same.
  if( !is.null( subset_id ) ){
    cells.use = as.character(my_df$ident) %in% as.character(subset_id)
  } else {
    cells.use = rownames(my_df)
  }
  p = ggplot() + geom_blank( aes_string( x = axes[1], y = axes[2] ), data = my_df )
  my_df = my_df[cells.use, ]
  
  # # Treat categorical variables one way and continuous one another way.
  # # For categorical, assign randomly-ordered diverging colors if none given or not enough given
  # # Convert to hexadecimal if any given as e.g. "red"
  is_categorical = (length(colour) > 0) && ( is.factor(my_df[[colour]]) | is.character(my_df[[colour]]) )
  if( overplot_adjust & is_categorical ){
    warning("Cannot adjust for overplotting with categorical variables due to color aggregation issues. 
            Continuing with `overplot_adjust=F`." )
    overplot_adjust = F
  }
  if( is_categorical ){
    is_default = ( length( cols.use ) == length( blue_gray_red ) ) && all( cols.use == blue_gray_red )
    if( is_default || length( cols.use ) < length( unique( my_df[[colour]] ) ) ){
      better_rainbow = scales::hue_pal()
      cols.use = ( my_df[[colour]] %>% unique %>% length %>% better_rainbow )
    } else if ( any( cols.use %in% colors() ) ){
      preserved_names = names(cols.use)
      cols.use = gplots::col2hex( cols.use )
      names(cols.use) = preserved_names
    }
    p = p + scale_color_manual(values = cols.use)    + scale_fill_manual(values = cols.use)
  } else { 
    if( (length( colour ) > 0) ){
      # Optional rank transformation
      if( use_rank ){
        my_df[[colour]] = rank(my_df[[colour]]) 
        p = p + labs(colour="Cell rank")
      } else {
        p = p + labs(colour="Log normalized expression")
      }
      # Set color scale by individual points, even if aggregating as in overplot_adjust
      my_limits = c(min(my_df[[colour]]), max(my_df[[colour]]))
      p = p + 
        scale_color_gradientn(colors = cols.use, limits=my_limits ) +
        scale_fill_gradientn( colors = cols.use, limits=my_limits ) 
    }
    p = p + xlab( axes[1] ) + ylab( axes[2] ) 
  }
  
 
  if( !overplot_adjust ){
    if( length( colour ) == 0 ){
      p = p + geom_point( aes_string(x = axes[1], y = axes[2]), colour = "grey25",
                          alpha = alpha, data = my_df,
                          size = 4 / log10( length( cells.use ) ) )  
    } else {
      p = p + geom_point(aes_string(x = axes[1], y = axes[2], colour = colour), 
                         alpha = alpha, data = my_df,
                         size = 4 / log10(length(cells.use))) 
      p = p + ggtitle( colour )
    }
  } else {
    if( length( colour ) == 0 ){
      p = p + geom_hex( aes_string( x = axes[1], y = axes[2], alpha = "..count.." ), fill = "grey25",
                    data = my_df )  
      p = p + ggtitle( axes_description )
    } else {
      hex_data = hexbin::hexbin(my_df)
      hex_data = data.frame( x = hex_data@xcm, 
                             y = hex_data@ycm, 
                             count = hex_data@count )
      names(hex_data)[1:2] = axes
      nearest_bin = FNN::get.knnx( query = my_df[axes], 
                                   data = hex_data[axes], 
                                   k = 1, algorithm = "cover_tree" )$nn.index %>% c
      bin_averages = aggregate_nice( my_df[[colour]], by = nearest_bin, FUN = mean )[, 1]
      hex_data[names(bin_averages), colour] = bin_averages
      p = p + geom_point( aes_string(x = axes[1], y = axes[2], size = "count", colour = colour ),
                          data = hex_data )
      hex_data = subset( hex_data, count > 20 )
      p = p + ggtitle( colour )
    }
  }
  if( fix_coords ){
    p = p + coord_fixed()
  }
  if( !show_axes ){
    p = p + theme(axis.line=element_blank(),
                  axis.ticks=element_blank(),
                  axis.text.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.title.x=element_blank(),
                  axis.title.y=element_blank() )
  }
    
  return(p)
}

## ------------------------------------------------------------------------
# Many thanks to the R cookbook for this function
# http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_(ggplot2)/ 
#
# Multiple plot function
#
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  library(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    nrow = cols, ncol = ceiling(numPlots/cols)) %>% t
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

save_plot_grid = function( dge, results_path, 
                           gene_list, gene_list_name, 
                           ncol, width, height, 
                           memory_saver = T, use_raw = F,
                           leg_pos   = c(0.9, 0.9),
                           title_pos = c(0.5, 0.9),
                           edit_fun = (function(p) return(p)),
                           ... ) {
  fix_legend = function(p) {
    p = p + labs(colour = "Log2 norm\nexpression")
    p = p + theme(title           = element_text(hjust = title_pos[[1]], vjust = title_pos[[2]]))
    p = p + theme(legend.position = c(                     leg_pos[[1]],           leg_pos[[2]]))
    p = p + theme(legend.title = element_text(hjust = 0.95))
    return(p)
  }

  if( memory_saver){
    dge@scale.data = matrix()
    if(use_raw){
      dge@data = matrix()
    } else {
      dge@raw.data = matrix()
    }
    gc()
  }
  {
    pdf(file.path(results_path, paste0(gene_list_name, ".pdf")), width = width, height = height )
    multiplot( plotlist = lapply(gene_list, custom_feature_plot, dge = dge, ...) %>%
                 lapply(fix_legend) %>% lapply(edit_fun), cols = ncol )
    dev.off()
  }
}

## ------------------------------------------------------------------------
#' Save plots from `custom_feature_plot`.
#'
#' @param dge Seurat object
#' @param results_path Where to save files.
#' @param colour A gene or type of metadata. Numeric zeroes plotted if `!is.element( colour, AvailableData( dge ) )`.
#' @param fig_name Figure gets named <fig_name>.pdf or <fig_name>.png or similar. If you put a name ending in ".png" or ".pdf", the extension is stripped off.
#' @param axes Character vector of length 2. Name of numeric variables available from `FetchData`.
#' @param axes_description Character. Used in file paths, so no spaces please.
#' @param alpha Numeric of length 1 between 0 and 1. Point transparency.
#' @param height Passed to ggsave.
#' @param width Passed to ggsave, but when you ask for a legend, it gets stretched a bit to make up for lost horizontal space.
#' @param types Atomic character vector; can be longer than 1 element. If contains "PDF", you get a PDF back. If "PDF_no_leg", you get a PDF with no legend. If "PNG_PDF_split", you get back the points and bare axes in a PNG, plus text-containing elements in a PDF with no points. By default, does all three. Matching is not case sensitive.
#' @param ... Additional arguments passed to `custom_feature_plot`.
#'
#' @export
tsne_colored = function(dge, results_path, colour = NULL, fig_name = NULL,
                        axes = c("tSNE_1", "tSNE_2"), axes_description = "TSNE", 
                        alpha = 1, height = 7, width = NA, 
                        types = c("PDF", "PDF_no_leg" ), ... ){
  
  # Sanitize input -- `aes_string` was choking on a gene with a hyphen (Nkx2-1)
  rownames( dge@data ) = make.names( rownames( dge@data ) )
  rownames( dge@raw.data ) = make.names( rownames( dge@raw.data ) )
  rownames( dge@scale.data ) = make.names( rownames( dge@scale.data ) )
  colour = make.names( colour )
  axes == make.names( axes )
  
  # More input cleaning
  types = tolower(types)
  if( is.null( fig_name ) ){ fig_name = colour }
  fig_name %<>% strip_suffix( ".pdf" )
  fig_name %<>% strip_suffix( ".png" )
  
  # Get plot
  p = custom_feature_plot(dge = dge, colour = colour, axes = axes, alpha = alpha, ... )
  
  # Save plots
  dir.create.nice( file.path( results_path, axes_description ) )
  if( "pdf" %in% types ){
    ggsave( filename = file.path( results_path, axes_description, paste0(fig_name, ".pdf") ),
            plot = p,
            width = width, height = height)
  } 
  if( any( c("pdf_noleg", "pdf_no_leg") %in% types ) ){
    ggsave( filename = file.path( results_path, axes_description, paste0(fig_name, "_no_leg.pdf") ),
            plot = p + theme(legend.position="none"),
            width = width, height = height)
  }
  if( any( c( "png_pdf_split", "pdf_png_split" ) %in% types ) ){
    # PNG no axis tick labels, no axis labels, and no legend
    ggsave( filename = file.path( results_path, axes_description, paste0(fig_name, ".png") ),
            plot = p + 
              theme(legend.position="none") +
              theme(axis.text.x  = element_blank(), 
                    axis.text.y  = element_blank()) + 
              xlab("") + ylab("") + ggtitle(""),
            width = width, height = height)
    
    # ==== PDF with no points ====
    # Copy plot and remove points
    p_no_pts = p
    p_no_pts$layers = p_no_pts$layers[1]
    # Add two points to get the right color legend 
    if(length(colour)!=0){
      max_idx = which.max( FetchDataZeroPad(dge, colour)[[1]] )[1]
      min_idx = which.min( FetchDataZeroPad(dge, colour)[[1]] )[1]
      p_no_pts = p_no_pts + geom_point( data = FetchDataZeroPad( dge, c( axes, colour ) )[c( max_idx, min_idx ) , ],
                                        aes_string( x = axes[[1]], y = axes[[2]], colour = colour ) )
    }
    ggsave( filename = file.path( results_path, axes_description, paste0(fig_name, "_no_pts.pdf") ),
            plot = p_no_pts ,
            width = width, height = height)
  }

}

#' Annotate a plot with cluster labels
#'
#' @export
#'
annot_ident_plot = function(dge, results_path, figname, ident.use = "ident", height = 7, width = 8, ... ){
  centers = aggregate.nice( FetchData(dge, c("tSNE_1", "tSNE_2")), by=FetchData(dge, ident.use), mean ) %>% as.data.frame
  centers$cluster = levels( FetchData(dge, ident.use)[[1]] )
  p = custom_feature_plot( dge, colour = ident.use, ... )
  p = p + geom_label( data = centers, aes_string(x = "tSNE_1", y = "tSNE_2", label = "cluster", size = 8 ) )
  ggsave(file.path(results_path, paste0(figname, ".pdf")), p, height = height, width = width)
  return(p)
}

## ------------------------------------------------------------------------
#' Save commonly needed summary plots: plain gray, eday, clusters, replicates, nUMI, nGene, and pseudotime if available.
#'
#' @export
misc_summary_info = function(dge, results_path, clusters_with_names = NULL,
                             axes = c("tSNE_1", "tSNE_2"), axes_description = "TSNE", alpha = 1 ){
  results_path = file.path( results_path, "summaries" )
  
  # # Plot summary, checking automatically whether the colour variable is available
  try_to_plot = function( fig_name, colour, ... ){
    if( length( colour ) == 0 || colour %in% AvailableData(dge) ){
      tsne_colored( dge = dge, results_path,
                    fig_name = fig_name, colour = colour, 
                    axes = axes, axes_description = axes_description, alpha = alpha, ...)
    } else {
      print( paste0( "Skipping summary of ", colour, " because it's not available." ) )
    }
  }
  
  try_to_plot( "plain_gray.pdf", colour = NULL )
  try_to_plot( "replicates.pdf", "rep" )
  try_to_plot( "cell_type.pdf" , "cell_type" )
  try_to_plot( "clusters.pdf"  , "ident" )
  try_to_plot( "classifier.pdf", "classifier_ident" )
  try_to_plot( "samples.pdf"   , "orig.ident" )
  try_to_plot( "nGenes.pdf"    , "nGenes" )
  try_to_plot( "nUMI.pdf"      , "nUMI" )
  try_to_plot( "branch.pdf"    , "branch" )
  try_to_plot( "pseudotime.pdf", "pseudotime" )
  try_to_plot( "day.pdf"       , "eday" )
  try_to_plot( "edayXgenotype.pdf"   , "edayXgenotype" )

  if( all( c("pseudotime", "eday") %in% AvailableData( dge ) ) ) {
    ggsave( filename = file.path( results_path, "pseudotime_by_eday_box.pdf"),
            plot = ggplot( FetchData( dge, c( "pseudotime", "eday" ) ), 
                           aes( y = pseudotime, x = factor( eday ) ) ) + geom_boxplot() )
  }
}


#' Save plots en masse.
#'
#' @param dge Seurat object with available t-SNE coords (or whatever's in `axes`) 
#' @param results_path: where to save the resulting plots
#' @param top_genes: deprecated; do not use
#' @param by_cluster: deprecated; do not use
#' @param gene_list: character vector consisting of gene names
#' @param gene_list_name: used in file paths so that you can call this function again with different `gene_list_name`
#    but the same results_path and it won't overwrite.
#' @param axes: any pair of numeric variables retrievable via FetchData. Defaults to `c("tSNE_1", "tSNE_2")`.
#' @param axes_description: used in file paths so that you can call this function again with different `axes_description` but the same `results_path` and it won't overwrite.
#' @param time_series: Uses `time_series` internally instead of `custom_feature_plot`. Changes defaults for
#' `axes` and `axes_description`.
#' @param alpha Transparency of points
#' @param ... Additional parameters are passed to `custom_feature_plot` or `time_series`
#' @export
save_feature_plots = function( dge, results_path, 
                               top_genes = NULL, 
                               by_cluster = NULL,
                               gene_list = NULL, 
                               gene_list_name = NULL, 
                               axes = NULL,
                               axes_description = NULL,
                               do_time_series = F,
                               alpha = 1, ... ){
  # # Adjust defaults sensibly
  if( do_time_series ){
    if( is.null( axes            ) )  { axes             = "pseudotime" }
    if( is.null( axes_description ) ) { axes_description = "pseudotime" }
  } else {
    if( is.null( axes             ) ) { axes = c( "tSNE_1", "tSNE_2" ) }
    if( is.null( axes_description ) ) { axes_description = "TSNE" }
  }
  
  # # Defaults to rene's markers if gene_list not given
  # # If gene_list is not given, gene_list_name is replaced with "rene_picks"
  # # gene_list_name defaults to "unknown" if only gene_list_name not given
  if( is.null( gene_list ) ){
    gene_list = get_rene_markers()$marker %>% harmonize_species(dge)
    if( !is.null( gene_list_name ) ){
      warning("Overwriting gene_list_name argument with 'rene_picks' since gene_list was not given.")
    }
    gene_list_name = "rene_picks"
  } else if(is.null(gene_list_name)){
    warning("Please fill in the gene_list_name argument. Defaulting to 'unknown'.")
    gene_list_name = "unknown"
  }
  
  if(!is.null(top_genes) || !is.null(by_cluster)){
    warning( paste ( "`top_genes` and `by_cluster` arguments have been deprecated.",
                     "If you want plots of cluster markers, use the new arg `gene_list_name`." ) )
  }
  
  # # Put all feature plots in one PDF
  no_data = c()
  feature_plots_path = file.path(results_path, "feature_plots", gene_list_name)
  dir.create.nice( feature_plots_path )
  dir.create.nice( file.path( feature_plots_path ) )
   
  gene_list = as.character( gene_list )
  for( gene_name in gene_list ){
    if( !do_time_series ){
      tsne_colored( dge, results_path = feature_plots_path, colour = gene_name, 
                    axes = axes, axes_description = axes_description, alpha = alpha, ... )
    } else {
      time_series_save( dge, results_path = feature_plots_path, gene = gene_name, ... )
    }
  } 
  cat( "Plots saved to", file.path( feature_plots_path ), "\n" )
}



