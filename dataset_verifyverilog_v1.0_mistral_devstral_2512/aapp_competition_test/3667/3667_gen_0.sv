module water_robots(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire [2:0]          well_count,
    input  wire [2:0]          pipe_count,
    input  wire [15:0]         well_x_0, well_y_0,
    input  wire [15:0]         well_x_1, well_y_1,
    input  wire [15:0]         well_x_2, well_y_2,
    input  wire [15:0]         well_x_3, well_y_3,
    input  wire [2:0]          pipe_start_0, pipe_start_1, pipe_start_2, pipe_start_3,
    input  wire [2:0]          pipe_start_4, pipe_start_5, pipe_start_6, pipe_start_7,
    input  wire [15:0]         pipe_end_x_0, pipe_end_y_0,
    input  wire [15:0]         pipe_end_x_1, pipe_end_y_1,
    input  wire [15:0]         pipe_end_x_2, pipe_end_y_2,
    input  wire [15:0]         pipe_end_x_3, pipe_end_y_3,
    input  wire [15:0]         pipe_end_x_4, pipe_end_y_4,
    input  wire [15:0]         pipe_end_x_5, pipe_end_y_5,
    input  wire [15:0]         pipe_end_x_6, pipe_end_y_6,
    input  wire [15:0]         pipe_end_x_7, pipe_end_y_7,
    output wire                result,
    output wire                done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CAPTURE = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    reg [2:0] well_count_reg;
    reg [2:0] pipe_count_reg;
    reg [15:0] well_x_reg [0:3];
    reg [15:0] well_y_reg [0:3];
    reg [2:0] pipe_start_reg [0:7];
    reg [15:0] pipe_end_x_reg [0:7];
    reg [15:0] pipe_end_y_reg [0:7];
    
    reg [7:0] i_reg, j_reg, k_reg;
    reg [15:0] ax_reg, ay_reg, bx_reg, by_reg;
    reg [15:0] cx_reg, cy_reg, dx_reg, dy_reg;
    reg [31:0] orient1_reg, orient2_reg, orient3_reg, orient4_reg;
    reg [31:0] orient12_reg, orient34_reg;
    reg [15:0] px_reg, py_reg;
    reg is_well_reg;
    reg [7:0] color_reg [0:7];
    reg [7:0] queue [0:7];
    reg [2:0] front_reg, rear_reg;
    reg [7:0] current_reg, neighbor_reg;
    reg conflict_reg;
    reg bipartite_reg;
    reg [7:0] adj [0:7];
    
    reg result_reg;
    reg done_reg;
    
    assign result = result_reg;
    assign done = done_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            result_reg <= 1'b0;
            done_reg <= 1'b0;
            
            well_count_reg <= 3'd0;
            pipe_count_reg <= 3'd0;
            
            integer i;
            for (i = 0; i < 4; i = i + 1) begin
                well_x_reg[i] <= 16'd0;
                well_y_reg[i] <= 16'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                pipe_start_reg[i] <= 3'd0;
                pipe_end_x_reg[i] <= 16'd0;
                pipe_end_y_reg[i] <= 16'd0;
                adj[i] <= 8'd0;
                color_reg[i] <= 8'd0;
            end
            
            front_reg <= 3'd0;
            rear_reg <= 3'd0;
            conflict_reg <= 1'b0;
            bipartite_reg <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end
                
                CAPTURE: begin
                    well_count_reg <= well_count;
                    pipe_count_reg <= pipe_count;
                    
                    well_x_reg[0] <= well_x_0;
                    well_y_reg[0] <= well_y_0;
                    well_x_reg[1] <= well_x_1;
                    well_y_reg[1] <= well_y_1;
                    well_x_reg[2] <= well_x_2;
                    well_y_reg[2] <= well_y_2;
                    well_x_reg[3] <= well_x_3;
                    well_y_reg[3] <= well_y_3;
                    
                    pipe_start_reg[0] <= pipe_start_0;
                    pipe_start_reg[1] <= pipe_start_1;
                    pipe_start_reg[2] <= pipe_start_2;
                    pipe_start_reg[3] <= pipe_start_3;
                    pipe_start_reg[4] <= pipe_start_4;
                    pipe_start_reg[5] <= pipe_start_5;
                    pipe_start_reg[6] <= pipe_start_6;
                    pipe_start_reg[7] <= pipe_start_7;
                    
                    pipe_end_x_reg[0] <= pipe_end_x_0;
                    pipe_end_y_reg[0] <= pipe_end_y_0;
                    pipe_end_x_reg[1] <= pipe_end_x_1;
                    pipe_end_y_reg[1] <= pipe_end_y_1;
                    pipe_end_x_reg[2] <= pipe_end_x_2;
                    pipe_end_y_reg[2] <= pipe_end_y_2;
                    pipe_end_x_reg[3] <= pipe_end_x_3;
                    pipe_end_y_reg[3] <= pipe_end_y_3;
                    pipe_end_x_reg[4] <= pipe_end_x_4;
                    pipe_end_y_reg[4] <= pipe_end_y_4;
                    pipe_end_x_reg[5] <= pipe_end_x_5;
                    pipe_end_y_reg[5] <= pipe_end_y_5;
                    pipe_end_x_reg[6] <= pipe_end_x_6;
                    pipe_end_y_reg[6] <= pipe_end_y_6;
                    pipe_end_x_reg[7] <= pipe_end_x_7;
                    pipe_end_y_reg[7] <= pipe_end_y_7;
                    
                    state <= COMPUTE;
                    i_reg <= 8'd0;
                    j_reg <= 8'd0;
                    k_reg <= 8'd0;
                    
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        adj[i] <= 8'd0;
                        color_reg[i] <= 8'd0;
                    end
                    
                    front_reg <= 3'd0;
                    rear_reg <= 3'd0;
                    conflict_reg <= 1'b0;
                    bipartite_reg <= 1'b1;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (i_reg < pipe_count_reg) begin
                        if (j_reg < i_reg) begin
                            j_reg <= j_reg + 8'd1;
                        end else begin
                            j_reg <= 8'd0;
                            
                            if (i_reg < pipe_count_reg - 1) begin
                                i_reg <= i_reg + 8'd1;
                            end else begin
                                i_reg <= 8'd0;
                                j_reg <= 8'd0;
                                k_reg <= 8'd0;
                                
                                integer i;
                                for (i = 0; i < 8; i = i + 1) begin
                                    color_reg[i] <= 8'd0;
                                end
                                
                                front_reg <= 3'd0;
                                rear_reg <= 3'd0;
                                conflict_reg <= 1'b0;
                                bipartite_reg <= 1'b1;
                            end
                        end
                    end else if (k_reg < pipe_count_reg) begin
                        if (color_reg[k_reg] == 8'd0) begin
                            color_reg[k_reg] <= 8'd1;
                            queue[rear_reg] <= k_reg;
                            rear_reg <= rear_reg + 3'd1;
                        end
                        
                        if (front_reg < rear_reg) begin
                            current_reg <= queue[front_reg];
                            front_reg <= front_reg + 3'd1;
                            
                            integer i;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (adj[current_reg][i] && color_reg[i] == 8'd0) begin
                                    color_reg[i] <= ~color_reg[current_reg];
                                    queue[rear_reg] <= i;
                                    rear_reg <= rear_reg + 3'd1;
                                end else if (adj[current_reg][i] && color_reg[i] == color_reg[current_reg]) begin
                                    conflict_reg <= 1'b1;
                                end
                            end
                        end
                        
                        if (conflict_reg) begin
                            bipartite_reg <= 1'b0;
                        end
                        
                        k_reg <= k_reg + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result_reg <= bipartite_reg;
                    done_reg <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    always @(*) begin
        if (state == COMPUTE && i_reg < pipe_count_reg && j_reg < i_reg) begin
            ax_reg = well_x_reg[pipe_start_reg[i_reg]];
            ay_reg = well_y_reg[pipe_start_reg[i_reg]];
            bx_reg = pipe_end_x_reg[i_reg];
            by_reg = pipe_end_y_reg[i_reg];
            cx_reg = well_x_reg[pipe_start_reg[j_reg]];
            cy_reg = well_y_reg[pipe_start_reg[j_reg]];
            dx_reg = pipe_end_x_reg[j_reg];
            dy_reg = pipe_end_y_reg[j_reg];
            
            if ((ax_reg == cx_reg && ay_reg == cy_reg) ||
                (ax_reg == dx_reg && ay_reg == dy_reg) ||
                (bx_reg == cx_reg && by_reg == cy_reg) ||
                (bx_reg == dx_reg && by_reg == dy_reg)) begin
                
                if (ax_reg == cx_reg && ay_reg == cy_reg) begin
                    px_reg = ax_reg;
                    py_reg = ay_reg;
                end else if (ax_reg == dx_reg && ay_reg == dy_reg) begin
                    px_reg = ax_reg;
                    py_reg = ay_reg;
                end else if (bx_reg == cx_reg && by_reg == cy_reg) begin
                    px_reg = bx_reg;
                    py_reg = by_reg;
                end else begin
                    px_reg = bx_reg;
                    py_reg = by_reg;
                end
                
                is_well_reg = 1'b0;
                integer k;
                for (k = 0; k < well_count_reg; k = k + 1) begin
                    if (well_x_reg[k] == px_reg && well_y_reg[k] == py_reg) begin
                        is_well_reg = 1'b1;
                    end
                end
                
                if (!is_well_reg) begin
                    adj[i_reg][j_reg] = 1'b1;
                    adj[j_reg][i_reg] = 1'b1;
                end
            end else begin
                orient1_reg = (bx_reg - ax_reg) * (cy_reg - ay_reg) - (by_reg - ay_reg) * (cx_reg - ax_reg);
                orient2_reg = (bx_reg - ax_reg) * (dy_reg - ay_reg) - (by_reg - ay_reg) * (dx_reg - ax_reg);
                orient3_reg = (dx_reg - cx_reg) * (ay_reg - cy_reg) - (dy_reg - cy_reg) * (ax_reg - cx_reg);
                orient4_reg = (dx_reg - cx_reg) * (by_reg - cy_reg) - (dy_reg - cy_reg) * (bx_reg - cx_reg);
                
                orient12_reg = orient1_reg * orient2_reg;
                orient34_reg = orient3_reg * orient4_reg;
                
                if (orient12_reg[31] && orient34_reg[31]) begin
                    adj[i_reg][j_reg] = 1'b1;
                    adj[j_reg][i_reg] = 1'b1;
                end
            end
        end
    end
endmodule