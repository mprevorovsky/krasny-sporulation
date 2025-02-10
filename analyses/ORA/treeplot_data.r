# from enrichplot sourcecode to export treeplot data to redraw clusters as desired

fill_termsim <- function(x, keep) {
    termsim <- x@termsim[keep, keep]
    termsim[which(is.na(termsim))] <- 0
    termsim2 <- termsim + t(termsim)
    for ( i in seq_len(nrow(termsim2)))
        termsim2[i, i] <- 1
    return(termsim2)
}

update_n <- function(x, showCategory) {
    if (!is.numeric(showCategory)) {
        if (inherits(x, 'list')) {
            showCategory <- showCategory[showCategory %in% names(x)]
        }
        return(showCategory)
    }

    ## geneSets <- geneInCategory(x) ## use core gene for gsea result
    n <- showCategory
    if (inherits(x, 'list')) {
        nn <- length(x)
    } else {
        nn <- nrow(x)
    }
    if (nn < n) {
        n <- nn
    }

    return(n)
}

get_word_freq <- function(wordd){     
    dada <- strsplit(wordd, " ")
    didi <- table(unlist(dada))
    didi <- didi[order(didi, decreasing = TRUE)]
    # Get the number of each word
    word_name <- names(didi)
    fun_num_w <- function(ww){
        sum(vapply(dada, function(w){ww %in% w}, FUN.VALUE = 1))
    }
    word_num <- vapply(word_name, fun_num_w, FUN.VALUE = 1)
    word_w <- word_num[order(word_num, decreasing = TRUE)]
}

get_wordcloud <- function(cluster, ggData, nWords){
    words <- ggData$name %>%
        gsub(" in ", " ", .) %>%
        gsub(" [0-9]+ ", " ", .) %>%
        gsub("^[0-9]+ ", "", .) %>%
        gsub(" [0-9]+$", "", .) %>%
        gsub(" [A-Za-z] ", " ", .) %>%
        gsub("^[A-Za-z] ", "", .) %>%
        gsub(" [A-Za-z]$", "", .) %>%
        gsub(" / ", " ", .) %>%
        gsub(" and ", " ", .) %>%
        gsub(" of ", " ", .) %>%
        gsub(",", " ", .) %>%
        gsub(" - ", " ", .)
    net_tot <- length(words)

    clusters <- unique(ggData$color2)
    words_i <- words[which(ggData$color2 == cluster)]

    sel_tot <- length(words_i)
    sel_w <- get_word_freq(words_i)
    net_w_all <- get_word_freq(words)
    net_w <- net_w_all[names(sel_w)]
    tag_size <- (sel_w/sel_tot)/(net_w/net_tot)
    tag_size <- tag_size[order(tag_size, decreasing = TRUE)]
    nWords <- min(nWords, length(tag_size))
    tag <- names(tag_size[seq_len(nWords)])

    # Order of words
    dada <- strsplit(words_i, " ")
    len <- vapply(dada, length, FUN.VALUE=1)
    rank <- NULL
    for(i in seq_len(sel_tot)) {
        rank <- c(rank, seq_len(len[i]))
    }

    word_data <- data.frame(word = unlist(dada), rank = rank)
    word_rank1 <- stats::aggregate(rank ~ word, data = word_data, sum)
    rownames(word_rank1) <- word_rank1[, 1]

    word_rank1 <- word_rank1[names(sel_w), ]
    # Get an average ranking order
    word_rank1[, 2] <- word_rank1[, 2]/as.numeric(sel_w)
    tag_order <- word_rank1[tag, ]
    tag_order <- tag_order[order(tag_order[, 2]), ]
    tag_clu_i <- paste(tag_order$word, collapse=" ")
}

treepart <- function(x, showCategory = 30, color = "p.adjust", nWords = 4, nCluster = 5, cex_category = 1, label_format = 30, xlim = NULL, fontsize = 4, offset = NULL,
                    offset_tiplab = 0.35, hclust_method = "ward.D", group_color = NULL,  extend = 0.3, hilight = TRUE, ...) {
    group <- p.adjust <- count<- NULL
    if (class(x) == "gseaResult")
        x@result$Count <- x$core_enrichment %>%
            strsplit(split = "/")  %>%
            vapply(length, FUN.VALUE = 1)   
    n <- update_n(x, showCategory)
    if (is.numeric(n)) {
        keep <- seq_len(n)
    } else {
        keep <- match(n, rownames(x@termsim))
    }
    
    if (length(keep) == 0) {
        stop("no enriched term found...")
    }
    ## Fill the upper triangular matrix completely
    termsim2 <- fill_termsim(x, keep)

    ## Use the ward.D method to avoid overlapping ancestor nodes of each group
    hc <- stats::hclust(stats::as.dist(1- termsim2),
                        method = hclust_method)
    clus <- stats::cutree(hc, nCluster)
    d <- data.frame(
        label = names(clus),
        color = x[keep, as.character(color)],
        count = x$Count[keep],
        cluster = clus,
        cluster_name = paste0("cluster_", as.numeric(clus)),
        go = as.data.frame(x)[keep,'ID']
    )
    #### from group_tree
    dat <- data.frame(name = names(clus), cls=paste0("cluster_", as.numeric(clus)))
    grp <- apply(table(dat), 2, function(x) names(x[x == 1]))  
    p <- ggtree(hc, branch.length = "none", show.legend=FALSE)
    # extract the most recent common ancestor
    noids <- lapply(grp, function(x) unlist(lapply(x, function(i) ggtree::nodeid(p, i))))
    roots <- unlist(lapply(noids, function(x) ggtree::MRCA(p, x)))
    # cluster data
    p <- ggtree::groupOTU(p, grp, "group") + aes_(color =~ group)
    pdata <- data.frame(name = p$data$label, color2 = p$data$group)
    pdata <- pdata[!is.na(pdata$name), ]
                           
    #### from add_cladelab
    cluster_color <- unique(pdata$color2)
    cluster_label <- sapply(cluster_color, get_wordcloud, ggData = pdata, nWords = nWords)
    names(cluster_label) <- cluster_color
    return(list(
        df = d,
        cluster_label = cluster_label,
        grp = grp,
        pdata = pdata
    ))
}