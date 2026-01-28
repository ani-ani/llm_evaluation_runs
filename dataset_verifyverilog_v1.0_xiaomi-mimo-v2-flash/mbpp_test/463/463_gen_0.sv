module maximum_product_subarray (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;                // Current index in array
    reg signed [7:0] current_val;   // Current element value
    reg signed [15:0] max_ending_here;
    reg signed [15:0] min_ending_here;
    reg signed [15:0] max_so_far;
    
    // Multiplication temporary wires
    wire signed [23:0] mult_max; // 8-bit * 8-bit = 16-bit, extended to 24 for safety
    wire signed [23:0] mult_min;
    
    assign mult_max = max_ending_here * current_val;
    assign mult_min = min_ending_here * current_val;

    // Internal control signals
    reg capture_inputs;
    reg inc_index;
    reg rst_products;
    reg set_done;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? LOAD : IDLE;
            LOAD:       next_state = (len == 4'd0) ? FINISH : COMPUTE;
            COMPUTE:    next_state = UPDATE;
            UPDATE:     begin
                            if (index < len - 1) next_state = COMPUTE;
                            else next_state = FINISH;
                        end
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            index <= 4'd0;
            max_ending_here <= 16'sd0;
            min_ending_here <= 16'sd0;
            max_so_far <= 16'sd0;
            current_val <= 8'sd0;
        end else begin
            state <= next_state;

            // Default control signals
            capture_inputs <= 1'b0;
            inc_index <= 1'b0;
            rst_products <= 1'b0;
            set_done <= 1'b0;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        result <= 16'sd0;
                        max_so_far <= 16'sd0;
                        // Products will be initialized in LOAD state
                    end
                end

                LOAD: begin
                    // Capture current value based on index
                    case (index)
                        4'd0: current_val <= arr_0;
                        4'd1: current_val <= arr_1;
                        4'd2: current_val <= arr_2;
                        4'd3: current_val <= arr_3;
                        4'd4: current_val <= arr_4;
                        4'd5: current_val <= arr_5;
                        4'd6: current_val <= arr_6;
                        4'd7: current_val <= arr_7;
                        default: current_val <= 8'sd0;
                    endcase
                    
                    // Initialize products for the first element
                    if (index == 4'd0 && len > 4'd0) begin
                        max_ending_here <= {{8{current_val[7]}}, current_val}; // Sign extend 8-bit to 16-bit
                        min_ending_here <= {{8{current_val[7]}}, current_val};
                        max_so_far <= {{8{current_val[7]}}, current_val};
                    end
                end

                COMPUTE: begin
                    // Calculate candidates
                    // 1. current element alone
                    // 2. current_max * current_val
                    // 3. current_min * current_val
                    // We handle this via comparison logic in UPDATE
                end

                UPDATE: begin
                    // Advance index
                    if (index < len - 1) begin
                        index <= index + 4'd1;
                        // Load next element for next cycle
                        case (index + 4'd1)
                            4'd0: current_val <= arr_0;
                            4'd1: current_val <= arr_1;
                            4'd2: current_val <= arr_2;
                            4'd3: current_val <= arr_3;
                            4'd4: current_val <= arr_4;
                            4'd5: current_val <= arr_5;
                            4'd6: current_val <= arr_6;
                            4'd7: current_val <= arr_7;
                            default: current_val <= 8'sd0;
                        endcase
                    end

                    // Update logic based on multiplication results
                    // Determine new max_ending_here
                    // Candidates: current_val, mult_max, mult_min
                    // If current_val is largest
                    if ((current_val >= mult_max) && (current_val >= mult_min)) begin
                        max_ending_here <= {{8{current_val[7]}}, current_val};
                    end else if (mult_max >= mult_min) begin
                        // mult_max is largest (or equal to min, pick max)
                        max_ending_here <= mult_max[15:0]; // Truncate/Keep lower 16 bits
                    end else begin
                        // mult_min is largest (only if min * val > max * val)
                        max_ending_here <= mult_min[15:0];
                    end

                    // Determine new min_ending_here
                    // Candidates: current_val, mult_max, mult_min
                    // If current_val is smallest
                    if ((current_val <= mult_max) && (current_val <= mult_min)) begin
                        min_ending_here <= {{8{current_val[7]}}, current_val};
                    end else if (mult_max <= mult_min) begin
                        min_ending_here <= mult_max[15:0];
                    end else begin
                        min_ending_here <= mult_min[15:0];
                    end

                    // Update global max
                    if (index == 4'd0) begin
                        // First element already initialized in LOAD
                    end else begin
                        // Use the newly calculated max_ending_here to update global max
                        if (max_ending_here > max_so_far) begin
                            max_so_far <= max_ending_here;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    if (len == 4'd0) begin
                        result <= 16'sd0;
                    end else begin
                        // Final check if the last updated max was larger than previous global
                        if (index == 4'd0 && len == 4'd1) begin
                            result <= max_so_far;
                        end else if (max_ending_here > max_so_far) begin
                            result <= max_ending_here;
                        end else begin
                            result <= max_so_far;
                        end
                    end
                end
            endcase
        end
    end

endmodule