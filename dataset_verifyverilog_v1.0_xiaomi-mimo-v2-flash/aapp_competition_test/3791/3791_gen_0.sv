module FindMinCyclicShift(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] p [0:7],
    input wire [3:0] n,
    output reg [15:0] min_dev,
    output reg [3:0] best_shift,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] shift_cnt;      // Current shift k (0 to n-1)
    reg [3:0] pos_cnt;        // Current position i (0 to n-1)
    reg [15:0] current_dev;   // Accumulated deviation for current shift
    reg [15:0] min_dev_reg;   // Minimum deviation found so far
    reg [3:0] best_shift_reg; // Shift that gave minimum deviation
    reg [2:0] p_val;          // Current p[i] value (0-7 after conversion)
    reg [2:0] target_val;     // Target value (i+k) mod n (0-7)
    reg [15:0] abs_diff;      // Absolute difference |p[i] - target|
    reg computation_done;     // Flag for computation completion
    reg [4:0] cycle_count;    // Safety counter

    // Wire declarations for combinational logic
    wire [2:0] p_indexed;     // p[i] converted to 0-indexed
    wire [2:0] shift_indexed; // shift value for comparison (1-indexed)
    wire signed [3:0] diff;   // Signed difference
    wire signed [15:0] current_dev_signed;
    wire signed [15:0] min_dev_reg_signed;
    wire update_min;          // Compare condition

    // Conversion: p values are 1-indexed, convert to 0-indexed internally
    assign p_indexed = p[pos_cnt][2:0] - 3'd1;

    // Calculate (i + k) mod n with 4-bit values
    wire [3:0] target_wire;
    assign target_wire = (pos_cnt + shift_cnt) % n;

    // Convert target to 0-7 range (since n <= 8)
    assign target_val = target_wire[2:0];

    // Signed difference for absolute value calculation
    assign diff = {1'b0, p_indexed} - {1'b0, target_val};

    // Absolute value logic
    always @(*) begin
        if (diff[3]) begin  // Negative
            abs_diff = {12'd0, -diff[2:0]};
        end else begin
            abs_diff = {12'd0, diff[2:0]};
        end
    end

    // Comparator: update if current_dev < min_dev_reg (or equal but smaller shift)
    assign current_dev_signed = {current_dev[15], current_dev[14:0]};
    assign min_dev_reg_signed = {min_dev_reg[15], min_dev_reg[14:0]};
    assign update_min = (current_dev_signed < min_dev_reg_signed) || 
                        ((current_dev_signed == min_dev_reg_signed) && (shift_cnt < best_shift_reg));

    // Shift index for output (1-indexed)
    assign shift_indexed = shift_cnt + 3'd1;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (computation_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_dev <= 16'd0;
            min_dev_reg <= 16'd0;
            best_shift <= 4'd0;
            best_shift_reg <= 4'd0;
            done <= 1'b0;
            shift_cnt <= 4'd0;
            pos_cnt <= 4'd0;
            current_dev <= 16'd0;
            computation_done <= 1'b0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        shift_cnt <= 4'd0;
                        pos_cnt <= 4'd0;
                        current_dev <= 16'd0;
                        min_dev_reg <= 16'd0;
                        best_shift_reg <= 4'd0;
                        computation_done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Calculate deviation for current position
                    current_dev <= current_dev + abs_diff;
                    pos_cnt <= pos_cnt + 4'd1;

                    // Check if we completed all positions for current shift
                    if (pos_cnt == n - 4'd1) begin
                        // Shift completed, check if it's minimum
                        if (update_min) begin
                            min_dev_reg <= current_dev + abs_diff;
                            best_shift_reg <= shift_cnt;
                        end

                        // Move to next shift
                        if (shift_cnt == n - 4'd1) begin
                            // All shifts completed
                            computation_done <= 1'b1;
                        end else begin
                            shift_cnt <= shift_cnt + 4'd1;
                            pos_cnt <= 4'd0;
                            current_dev <= 16'd0;
                        end
                    end

                    // Safety: prevent infinite loop
                    if (cycle_count >= 5'd28) begin
                        computation_done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    min_dev <= min_dev_reg;
                    best_shift <= best_shift_reg + 4'd1;  // Convert to 1-indexed
                    computation_done <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Update state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule