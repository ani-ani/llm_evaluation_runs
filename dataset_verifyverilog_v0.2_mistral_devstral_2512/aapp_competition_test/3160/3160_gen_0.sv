module avg_operations (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_mask,
    input [7:0] head_mask,
    output reg [31:0] result_num,
    output reg [31:0] result_den,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        GENERATE_CONFIGS,
        CALCULATE_LENGTH,
        ACCUMULATE,
        DIVIDE,
        DONE_STATE
    } state_t;

    state_t current_state, next_state;

    // Configuration generation
    reg [7:0] config_counter;
    reg [7:0] current_config;
    reg [7:0] temp_head_mask;

    // Length calculation
    reg [7:0] temp_bits;
    reg [15:0] step_count;
    reg [7:0] k;
    reg [7:0] bit_pos;

    // Accumulation
    reg [31:0] total_sum;
    reg [31:0] total_configs;

    // Division
    reg [31:0] shift_amount;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            config_counter <= 0;
            current_config <= 0;
            temp_head_mask <= 0;
            temp_bits <= 0;
            step_count <= 0;
            k <= 0;
            bit_pos <= 0;
            total_sum <= 0;
            total_configs <= 0;
            shift_amount <= 0;
            result_num <= 0;
            result_den <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_CONFIGS;
                    config_counter = 0;
                    current_config = 0;
                    total_sum = 0;
                    total_configs = 0;
                    done = 0;
                end
            end
            GENERATE_CONFIGS: begin
                if (config_counter == (1 << $clog2($bits(char_mask) - $clog2(char_mask)))) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = CALCULATE_LENGTH;
                    temp_head_mask = head_mask | (current_config & char_mask);
                    temp_bits = temp_head_mask;
                    step_count = 0;
                end
            end
            CALCULATE_LENGTH: begin
                k = $clog2(temp_bits);
                if (k == 0) begin
                    next_state = ACCUMULATE;
                end else begin
                    bit_pos = 0;
                    while (bit_pos < 8) begin
                        if (temp_bits[bit_pos]) begin
                            k = k - 1;
                            if (k == 0) begin
                                temp_bits[bit_pos] = 0;
                                step_count = step_count + 1;
                                break;
                            end
                        end
                        bit_pos = bit_pos + 1;
                    end
                end
            end
            ACCUMULATE: begin
                total_sum = total_sum + step_count;
                total_configs = total_configs + 1;
                config_counter = config_counter + 1;
                current_config = current_config + 1;
                next_state = GENERATE_CONFIGS;
            end
            DIVIDE: begin
                shift_amount = $clog2(total_configs);
                result_num = total_sum << (32 - shift_amount);
                result_den = 1 << shift_amount;
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                done = 1;
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

endmodule