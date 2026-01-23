module BookPresentationMinimizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] B,
    input [3:0] G,
    input [5:0] edge_count,
    input [3:0] edges_boy [0:15],
    input [3:0] edges_girl [0:15],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] CHECK_EDGE  = 3'd2;
    localparam [2:0] AFTER_CHECK = 3'd3;
    localparam [2:0] NEXT_SUBSET = 3'd4;
    localparam [2:0] FINISH      = 3'd5;

    reg [2:0] state, next_state;
    
    // Data latches
    reg [3:0] latched_B;
    reg [3:0] latched_G;
    reg [5:0] latched_edge_count;
    reg [3:0] latched_edges_boy [0:15];
    reg [3:0] latched_edges_girl [0:15];
    
    // Algorithm registers
    reg [7:0] current_subset;
    reg [4:0] min_cover;
    reg [4:0] edge_counter;
    reg cover_valid;
    
    integer i;

    // Popcount function
    function [3:0] popcount;
        input [7:0] vec;
        integer i;
        begin
            popcount = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                if (vec[i]) popcount = popcount + 4'd1;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            current_subset <= 8'd0;
            min_cover <= 5'd0;
            edge_counter <= 5'd0;
            cover_valid <= 1'b0;
            latched_B <= 4'd0;
            latched_G <= 4'd0;
            latched_edge_count <= 6'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                latched_edges_boy[i] <= 4'd0;
                latched_edges_girl[i] <= 4'd0;
            end
            
            result <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        latched_B <= B;
                        latched_G <= G;
                        latched_edge_count <= edge_count;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < edge_count) begin
                                latched_edges_boy[i] <= edges_boy[i];
                                latched_edges_girl[i] <= edges_girl[i];
                            end
                        end
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    min_cover <= latched_B + latched_G;
                    current_subset <= 8'd0;
                    edge_counter <= 5'd0;
                    cover_valid <= 1'b1;
                    next_state <= CHECK_EDGE;
                end
                
                CHECK_EDGE: begin
                    if (edge_counter < latched_edge_count) begin
                        if (!current_subset[latched_edges_boy[edge_counter]] && 
                            !current_subset[latched_B + latched_edges_girl[edge_counter]]) begin
                            cover_valid <= 1'b0;
                        end
                        edge_counter <= edge_counter + 5'd1;
                        next_state <= CHECK_EDGE;
                    end else begin
                        next_state <= AFTER_CHECK;
                    end
                end
                
                AFTER_CHECK: begin
                    if (cover_valid) begin
                        if (popcount(current_subset) < min_cover) begin
                            min_cover <= popcount(current_subset);
                        end
                    end
                    next_state <= NEXT_SUBSET;
                end
                
                NEXT_SUBSET: begin
                    current_subset <= current_subset + 8'd1;
                    if (current_subset < (8'd1 << (latched_B + latched_G)) - 8'd1) begin
                        edge_counter <= 5'd0;
                        cover_valid <= 1'b1;
                        next_state <= CHECK_EDGE;
                    end else begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_cover;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule