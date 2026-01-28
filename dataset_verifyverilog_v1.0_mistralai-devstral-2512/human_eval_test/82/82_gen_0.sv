module PrimeLengthChecker(
    input clk,
    input rst_n,
    input start,
    input [3:0] str_len,
    input [7:0] string_data [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [0:0] IDLE    = 1'b0;
    localparam [0:0] PROCESS = 1'b1;
    
    reg [0:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;

    // Prime LUT for numbers 0-8
    wire is_prime;
    assign is_prime = (str_len == 4'd2) || (str_len == 4'd3) || 
                      (str_len == 4'd5) || (str_len == 4'd7);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    result <= is_prime;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule