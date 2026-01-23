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

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] subset;
    reg [7:0] max_subset;
    reg [7:0] edge_idx;
    reg [4:0] min_cover;
    reg [4:0] current_cover;
    reg cover_valid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 8'd0;
            max_subset <= 8'd0;
            edge_idx <= 8'd0;
            min_cover <= 5'd0;
            current_cover <= 5'd0;
            cover_valid <= 1'b1;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        max_subset <= (B + G);
                        min_cover <= (B + G);
                        subset <= 8'd0;
                        edge_idx <= 8'd0;
                        cover_valid <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (edge_idx < edge_count) begin
                        if (cover_valid) begin
                            if ((subset[edges_boy[edge_idx]] == 1'b0) && 
                                (subset[B + edges_girl[edge_idx]] == 1'b0)) begin
                                cover_valid <= 1'b0;
                            end
                            edge_idx <= edge_idx + 8'd1;
                        end else begin
                            edge_idx <= edge_idx + 8'd1;
                        end
                    end else begin
                        if (cover_valid) begin
                            current_cover <= $clog2(subset + 1'b1);
                            if (current_cover < min_cover) begin
                                min_cover <= current_cover;
                            end
                        end
                        
                        if (subset == max_subset) begin
                            state <= FINISH;
                        end else begin
                            subset <= subset + 8'd1;
                            edge_idx <= 8'd0;
                            cover_valid <= 1'b1;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_cover;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule