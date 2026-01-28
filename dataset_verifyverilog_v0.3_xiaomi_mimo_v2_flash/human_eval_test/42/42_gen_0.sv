module incr_list(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;
    
    reg [1:0] state;
    reg [2:0] counter;  // Index counter (0-7)
    reg [3:0] len_reg;  // Store length
    
    // Combinational signal for completion
    wire processing_done;
    assign processing_done = (counter >= len_reg);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            len_reg <= 4'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 3'd0;
                    if (start) begin
                        len_reg <= len;
                        valid <= 1'b0;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    // Process current element
                    case (counter)
                        3'd0: result_0 <= arr_0 + 8'd1;
                        3'd1: result_1 <= arr_1 + 8'd1;
                        3'd2: result_2 <= arr_2 + 8'd1;
                        3'd3: result_3 <= arr_3 + 8'd1;
                        3'd4: result_4 <= arr_4 + 8'd1;
                        3'd5: result_5 <= arr_5 + 8'd1;
                        3'd6: result_6 <= arr_6 + 8'd1;
                        3'd7: result_7 <= arr_7 + 8'd1;
                    endcase
                    
                    // Increment counter
                    counter <= counter + 3'd1;
                    
                    // Check if done processing
                    if (processing_done) begin
                        state <= DONE_STATE;
                        valid <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    counter <= 3'd0;
                    len_reg <= 4'd0;
                    result_0 <= 8'd0;
                    result_1 <= 8'd0;
                    result_2 <= 8'd0;
                    result_3 <= 8'd0;
                    result_4 <= 8'd0;
                    result_5 <= 8'd0;
                    result_6 <= 8'd0;
                    result_7 <= 8'd0;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule