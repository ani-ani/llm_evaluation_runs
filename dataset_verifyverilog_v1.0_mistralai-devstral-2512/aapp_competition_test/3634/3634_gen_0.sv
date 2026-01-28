module sensor_triplet_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] snow_levels [0:255],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CALC  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] i_reg, j_reg, k_reg;
    reg [31:0] left_count, right_count;
    reg [31:0] temp_result;
    reg [7:0] current_j_value;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd10000;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            k_reg <= 8'd0;
            left_count <= 32'd0;
            right_count <= 32'd0;
            temp_result <= 32'd0;
            current_j_value <= 8'd0;
            cycle_count <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC;
                    temp_result = 32'd0;
                    j_reg = 8'd0;
                    cycle_count = 32'd0;
                end
            end

            CALC: begin
                // Calculate left_count for current j
                if (i_reg < j_reg) begin
                    if (snow_levels[i_reg] < current_j_value) begin
                        left_count = left_count + 32'd1;
                    end
                    i_reg = i_reg + 8'd1;
                end
                // Calculate right_count for current j
                else if (k_reg < 256) begin
                    if (snow_levels[k_reg] > current_j_value) begin
                        right_count = right_count + 32'd1;
                    end
                    k_reg = k_reg + 8'd1;
                end
                // Update result and move to next j
                else begin
                    temp_result = temp_result + (left_count * right_count);
                    j_reg = j_reg + 8'd1;
                    
                    // Reset counters for next j
                    i_reg = 8'd0;
                    k_reg = 8'd0;
                    left_count = 32'd0;
                    right_count = 32'd0;
                    
                    // Update current_j_value for next iteration
                    if (j_reg < 256) begin
                        current_j_value = snow_levels[j_reg];
                    end
                    
                    // Check if all j's processed or cycle limit reached
                    if (j_reg >= 256 || cycle_count >= MAX_CYCLES) begin
                        next_state = DONE_STATE;
                    end
                end
                
                cycle_count = cycle_count + 32'd1;
            end

            DONE_STATE: begin
                result = temp_result % 32'd1000000009;
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule