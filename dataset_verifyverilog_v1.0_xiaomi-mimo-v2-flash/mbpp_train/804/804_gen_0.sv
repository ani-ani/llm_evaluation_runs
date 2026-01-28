module ProductEvenCheck (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] index;          // Current element index to check
    reg even_found;           // Flag to track if even number found
    reg [3:0] len_reg;        // Store len for processing
    reg processing;           // Indicates if processing is active

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register and reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            even_found <= 1'b0;
            len_reg <= 4'd0;
            processing <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        processing <= 1'b1;
                        len_reg <= len;
                        index <= 4'd0;
                        even_found <= 1'b0;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check LSB of current element (arr[index][0])
                    // Only check if index < len_reg
                    if (index < len_reg) begin
                        if (arr[index][0] == 1'b0) begin
                            even_found <= 1'b1;
                        end
                        index <= index + 4'd1;
                    end
                    
                    // Exit condition: all elements checked or timeout
                    if (index >= len_reg || cycle_count >= MAX_CYCLES) begin
                        result <= even_found;  // 1 if even found, 0 if all odd
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    processing <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK: begin
                // When all elements checked or timeout, go to finish
                if (index >= len_reg || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule