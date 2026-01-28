module ExchangeParity(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:15],
    input wire [7:0] arr2 [0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] COMPUTE_RESULT = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [3:0] odd1_count;
    reg [3:0] even2_count;
    reg [3:0] len_reg;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALCULATE;
                else
                    next_state = IDLE;
            end
            CALCULATE: begin
                if (index >= len_reg)
                    next_state = COMPUTE_RESULT;
                else
                    next_state = CALCULATE;
            end
            COMPUTE_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            odd1_count <= 4'd0;
            even2_count <= 4'd0;
            len_reg <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        len_reg <= len;
                        index <= 4'd0;
                        odd1_count <= 4'd0;
                        even2_count <= 4'd0;
                    end
                end
                
                CALCULATE: begin
                    // Count odd elements in arr1
                    if (arr1[index][0]) begin
                        odd1_count <= odd1_count + 4'd1;
                    end
                    
                    // Count even elements in arr2
                    if (!arr2[index][0]) begin
                        even2_count <= even2_count + 4'd1;
                    end
                    
                    // Increment index
                    index <= index + 4'd1;
                end
                
                COMPUTE_RESULT: begin
                    // Compare odd1_count with even2_count
                    if (odd1_count <= even2_count) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Reset for next operation
                    index <= 4'd0;
                    odd1_count <= 4'd0;
                    even2_count <= 4'd0;
                end
                
                default: begin
                    // Reset to safe state
                    index <= 4'd0;
                    odd1_count <= 4'd0;
                    even2_count <= 4'd0;
                end
            endcase
        end
    end

endmodule