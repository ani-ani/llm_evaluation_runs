module ZeroSumPairDetector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] outer_idx;
    reg [3:0] inner_idx;
    reg [7:0] sum;
    reg found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SCANNING;
                end else begin
                    next_state = IDLE;
                end
            end

            SCANNING: begin
                if (found || (outer_idx == len - 1'b1 && inner_idx == len) || cycle_count >= MAX_CYCLES) begin
                    next_state = COMPLETE;
                end else begin
                    next_state = SCANNING;
                end
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register with reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            outer_idx <= 4'd0;
            inner_idx <= 4'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    found <= 1'b0;
                    outer_idx <= 4'd0;
                    inner_idx <= 4'd0;
                    cycle_count <= 8'd0;
                end

                SCANNING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!found) begin
                        sum <= arr[outer_idx] + arr[inner_idx];
                        
                        if (sum == 8'd0) begin
                            found <= 1'b1;
                        end
                        
                        // Update indices
                        if (inner_idx == len - 1'b1) begin
                            outer_idx <= outer_idx + 4'd1;
                            inner_idx <= outer_idx + 4'd1;
                        end else begin
                            inner_idx <= inner_idx + 4'd1;
                        end
                    end
                    
                    done <= 1'b0;
                end

                COMPLETE: begin
                    result <= found;
                    done <= 1'b1;
                end

                default: begin
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule