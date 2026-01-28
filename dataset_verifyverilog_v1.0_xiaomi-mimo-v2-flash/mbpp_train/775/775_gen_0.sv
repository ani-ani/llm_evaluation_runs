module parity_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] UPDATE    = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] index;           // Index from 0 to 7
    reg [7:0] temp_result;     // Accumulated result (bitmask)
    reg [7:0] cycle_count;     // For max cycle enforcement
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Combinational logic for next state and outputs
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
                // Check parity for current index
                if (index < 8'd8) begin
                    next_state = UPDATE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            UPDATE: begin
                next_state = CHECK;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            temp_result <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    index <= 3'd0;
                    temp_result <= 8'd0;
                    cycle_count <= 8'd0;
                end
                
                CHECK: begin
                    if (index < 8'd8) begin
                        // Check current index parity
                        if (arr[index][0] == index[0]) begin
                            // Parity matches, continue
                            temp_result[index] <= 1'b1;
                        end else begin
                            // Parity mismatch, mark as failure for this index
                            temp_result[index] <= 1'b0;
                        end
                    end
                end
                
                UPDATE: begin
                    index <= index + 3'd1;
                    
                    // Early exit if current index failed
                    if (!temp_result[index]) begin
                        // Don't need to check further
                        index <= 3'd8;
                    end
                end
                
                FINISH: begin
                    // Check if all bits in temp_result are set
                    if (temp_result == 8'hFF && cycle_count <= MAX_CYCLES) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule