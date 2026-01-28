module is_sorted_check (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,          // Number of valid elements (1-8)
    output reg result,        // 1 if sorted, 0 if not
    output reg done           // Pulse high when computation complete
);

    // State machine states
    reg [2:0] state;
    reg [3:0] idx;
    reg sorted_reg;
    
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam DONE = 3'b010;
    
    // Array to store inputs (for sequential access)
    reg [7:0] arr_reg [0:7];
    reg [3:0] len_reg;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            idx <= 0;
            sorted_reg <= 1;
            len_reg <= 0;
            // Clear array
            for (i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && len > 1) begin
                        // Capture inputs
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        len_reg <= len;
                        idx <= 1;  // Start from second element
                        sorted_reg <= 1;
                        state <= CHECK;
                    end else if (start && len <= 1) begin
                        // Single element or empty is trivially sorted
                        result <= 1;
                        done <= 1;
                        state <= DONE;
                    end
                end
                
                CHECK: begin
                    // Compare arr_reg[idx-1] with arr_reg[idx]
                    if (arr_reg[idx-1] > arr_reg[idx]) begin
                        sorted_reg <= 0;
                        // Early termination - continue to process remaining for timing consistency
                    end
                    
                    if (idx == len_reg - 1) begin
                        // Last comparison done
                        result <= sorted_reg;
                        done <= 1;
                        state <= DONE;
                    end else begin
                        idx <= idx + 1;
                    end
                end
                
                DONE: begin
                    done <= 0;  // Pulse done for one cycle
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule