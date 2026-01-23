module count_bidirectional #(
    parameter MAX_PAIRS = 8,
    parameter DATA_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr_a [0:MAX_PAIRS-1],
    input wire [DATA_WIDTH-1:0] arr_b [0:MAX_PAIRS-1],
    input wire [3:0] valid_pairs,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COMPARE  = 3'd1;
    localparam [2:0] INCR_J   = 3'd2;
    localparam [2:0] INCR_I   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    reg [2:0] state, next_state;
    reg [3:0] i, j;
    reg [7:0] count;
    reg comparison_result;
    reg [7:0] cycles;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycles <= 8'd0;
        end else begin
            cycles <= cycles + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Handle special cases
                        if (valid_pairs < 4'd2) begin
                            state <= FINISH;
                            result <= 8'd0;
                        end else begin
                            state <= COMPARE;
                            i <= 4'd0;
                            j <= 4'd1;
                            count <= 8'd0;
                            cycles <= 8'd0;
                        end
                    end
                end
                
                COMPARE: begin
                    if ((i < valid_pairs) && (j < valid_pairs)) begin
                        comparison_result <= (arr_a[i] == arr_b[j]) && (arr_b[i] == arr_a[j]);
                        state <= INCR_J;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                INCR_J: begin
                    if (comparison_result) begin
                        count <= count + 8'd1;
                    end
                    
                    if (j < (valid_pairs - 4'd1)) begin
                        j <= j + 4'd1;
                        state <= COMPARE;
                    end else begin
                        state <= INCR_I;
                    end
                end
                
                INCR_I: begin
                    if (i < (valid_pairs - 4'd2)) begin
                        i <= i + 4'd1;
                        j <= i + 4'd2;
                        state <= COMPARE;
                    end else begin
                        result <= count;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                    
                    // Safety timeout
                    if (cycles > 8'd200) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule