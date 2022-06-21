using PlotlyJS
using DataFrames
using CSV


#to do
#2d and 3d plots 
# with brushes

#pairs figures

#maddie - look at json
#prim figures once we write it.

#does reopt have graphics for capacity and or operations etc for optimal solution?

#can we compare to non-RDM reopt results?

#visualizations in julia for RDM REopt

function extract_uncertainties(df_results)
"""
This function takes in a dataframe of results and returns a tuple containing 
1) dataframe containing uncertainties and values for all SOW (dataframe)
2) a list of uncertainty names as strings (list)
3) a count of all uncertainties considered (integer)
"""

    #take a subset of uncertainties from the results dataframe passed to the function
    uncert_data = df_results[!,r"Uncertainty_"]
    #create a list of uncertainties and remove "_uncertainty" from name
    uncert_list = names(uncert_data)
    uncert_list .=replace.(uncert_list,"Uncertainty_"=>"")

    #count the number of uncertainties.
    uncert_count = size(uncert_list, 1)

    return (uncert_data, uncert_list, uncert_count)

end


function uncertainty_boxplots(df_results)
    """
    This function takes in a dataframe of results from reopt and outputs a boxplot visualization of each uncertainty
    This function has a limit of five (5) uncertainties. To enable more users will have to add elseif statements to the if elseif control flow
    """
    
    #extract the uncertainties from results
    uncertainties = extract_uncertainties(df_results)
    #uncert data
    uncert_data = uncertainties[1]
    #uncert_list of names
    uncert_list = uncertainties[2]
    #count of uncertainties
    uncert_count = uncertainties[3]
    
    #make subplots for the number of uncertainties in the data passed to function
    
    plts = make_subplots(rows = 1, cols=uncert_count, horizontal_spacing=.11)
    
    #create traces for each uncertainty
    for index in enumerate(names(uncert_data))
        add_trace!(plts, box(uncert_data, y=uncert_data[!,index[1]], boxpoints="all", kind="box",name=""),  row=1, col=index[1])
    end
    
    #relayout to add yaxis titles. Is there a better approach?
    if uncert_count == 1
        relayout!(plts, showlegend=false, title_text="Uncertainties", 
                yaxis=attr(title_text  = uncert_list[1], title_standoff=0), 
            )
    elseif uncert_count == 2
        relayout!(plts, showlegend=false, title_text="Uncertainties", 
                yaxis=attr(title_text  = uncert_list[1], title_standoff=0), 
                yaxis2=attr(title_text = uncert_list[2], title_standoff=0)
            )
    elseif uncert_count == 3
        relayout!(plts, showlegend=false, title_text="Uncertainties", 
                yaxis=attr(title_text  = uncert_list[1], title_standoff=0), 
                yaxis2=attr(title_text = uncert_list[2], title_standoff=0),
                yaxis3=attr(title_text = uncert_list[3], title_standoff=0)
            )
        
    elseif uncert_count == 4
        relayout!(plts, showlegend=false, title_text="Uncertainties", 
                yaxis=attr(title_text  = uncert_list[1], title_standoff=0), 
                yaxis2=attr(title_text = uncert_list[2], title_standoff=0), 
                yaxis3=attr(title_text = uncert_list[3], title_standoff=0),
                yaxis4=attr(title_text = uncert_list[4], title_standoff=0)
            )
    
    elseif uncert_count == 5
        relayout!(plts, showlegend=false, title_text="Uncertainties", 
                yaxis=attr(title_text  = uncert_list[1], title_standoff=0), 
                yaxis2=attr(title_text = uncert_list[2], title_standoff=0), 
                yaxis3=attr(title_text = uncert_list[3], title_standoff=0),
                yaxis4=attr(title_text = uncert_list[4], title_standoff=0),
                yaxis5=attr(title_text = uncert_list[5], title_standoff=0)
            )
    end

    display(plts)
end



#multi-dimensional plot of future states of the world
function multidim_sow(df_results)
    """
    This function takes in a rdmreopt dataframe of results and outputs a mutli-dimensional plot of the future states of the world 
    with each uncertainty represnted by a dimension
    #currently requires a minimum of three (3) uncertainties and maximum of five (5) uncertainties
    """

    dimcheckerror = "Dimensions are outside the bounds of this function - minimum of 2 and maximum of 5 dimensions"

    #extract the uncertainties from results
    uncertainties = extract_uncertainties(df_results)
    #uncert data
    uncert_data = uncertainties[1]
    #uncert_list of names
    uncert_list = uncertainties[2]
    #count of uncertainties
    uncert_count = uncertainties[3]

    if uncert_count ==2
        scat = scatter(
            uncert_data,
            x=uncert_data[!,1],
            y=uncert_data[!,2],
            mode= "markers",
            marker_size = 6
        )
        layout = Layout(
            title=attr(text="Future States of the World", y=0.95, x=0.4),        
            scene = attr(     
                xaxis_title = uncert_list[1],
                yaxis_title = uncert_list[2]
            ),
            margin=attr(r=20, b=10, l=10, t=10)
        )

    elseif uncert_count==3 
        scat = scatter3d(
            uncert_data,
            x=uncert_data[!,1],
            y=uncert_data[!,2],
            z=uncert_data[!,3], 
            type = "scatter3d",
            mode= "markers",
            marker_size = 6
        )
        layout = Layout(
            title=attr(text="Future States of the World", y=0.95, x=0.4),        
            scene = attr(     
                xaxis_title = uncert_list[1],
                yaxis_title = uncert_list[2],
                zaxis_title = uncert_list[3]
            ),
            margin=attr(r=20, b=10, l=10, t=10)
        )

    elseif uncert_count==4
        println("4 uncert")
        scat = scatter3d(
            uncert_data,
            x=uncert_data[!,1],
            y=uncert_data[!,2],
            z=uncert_data[!,3], 
            type = "scatter3d",
            mode= "markers",
            marker=attr(size=6, color=uncert_data[!,4], colorscale="Viridis",showscale=true, colorbar_title=uncert_list[4],colorbar_titleside="right",colorbar_len=0.8 ),
        )
        layout = Layout(
            title=attr(text="Future States of the World", y=0.95, x=0.4),        
            scene = attr(     
                xaxis_title = uncert_list[1],
                yaxis_title = uncert_list[2],
                zaxis_title = uncert_list[3]
            ),
            margin=attr(r=20, b=10, l=10, t=10)
        )
    
    elseif uncert_count==5
        scat = scatter3d(
            uncert_data,
            x=uncert_data[!,1],
            y=uncert_data[!,2],
            z=uncert_data[!,3], 
            type = "scatter3d",
            mode= "markers",
            marker=attr(size=6, color=uncert_data[!,4], colorscale="Viridis",showscale=true, colorbar_title=uncert_list[4],colorbar_titleside="right",colorbar_len=0.8 ),
        )
        layout = Layout(
            title=attr(text="Future States of the World", y=0.95, x=0.4),        
            scene = attr(     
                xaxis_title = uncert_list[1],
                yaxis_title = uncert_list[2],
                zaxis_title = uncert_list[3]
            ),
            margin=attr(r=20, b=10, l=10, t=10)
        )

    #else outside of bounds of this function and return dimcheckerror
    

    else
        return dimcheckerror
    
    end
    #plot and display
    println("here")
    display(plot(scat, layout))
    #plt = plot(scat, layout)
    #display(plt)
end
