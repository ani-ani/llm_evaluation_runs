module painting2x2 (
    input clk, rst_n, start,
    input [3:0] target,
    output reg [3:0] painted,
    output reg [2:0] min_diff,
    output reg done
);
    
    // States for the FSM
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [1:0] white_idx, black_idx;
    reg [2:0] min_cost;
    reg [1:0] best_white, best_black;
    reg [2:0] current_cost;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_cost <= 3'd4;
            white_idx <= 2'd0;
            black_idx <= 2'd0;
            best_white <= 2'd0;
            best_black <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        white_idx <= 2'd0;
                        black_idx <= 2'd0;
                        min_cost <= 3'd4;
                    end
                end
                
                COMPUTE: begin
                    if (white_idx < 2'd3) begin
                        if (black_idx < 2'd3) begin
                            if (white_idx != black_idx) begin
                                // Calculate cost for this assignment
                                current_cost = (target[white_idx] ? 1'b1 : 1'b0) + (target[black_idx] ? 1'b0 : 1'b1);
                                if (current_cost < min_cost) begin
                                    min_cost <= current_cost;
                                    best_white <= white_idx;
                                    best_black <= black_idx;
                                end
                            end
                            // Next black index
                            if (black_idx == 2'd2) begin
                                black_idx <= 2'd0;
                                white_idx <= white_idx + 2'd1;
                            end else begin
                                black_idx <= black_idx + 2'd1;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Reconstruct painted image
                    painted <= target;
                    painted[best_white] <= 1'b0;
                    painted[best_black] <= 1'b1;
                    min_diff <= min_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule