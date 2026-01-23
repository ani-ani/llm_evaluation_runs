module min_perm_deviation (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [63:0] p_in,
    output reg [15:0] min_deviation,
    output reg [2:0] best_shift,
    output reg done
);

    // Internal state definitions
    typedef enum logic [1:0] {
        IDLE,
        INIT,
        ITERATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] shift_count;
    reg [15:0] current_deviation;
    reg [15:0] min_deviation_reg;
    reg [2:0] best_shift_reg;
    reg [15:0] temp_deviation;
    reg [3:0] count_greater;
    reg [3:0] count_less;

    // Unpacked permutation
    reg [7:0] p [0:7];

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            shift_count <= 0;
            current_deviation <= 0;
            min_deviation_reg <= 0;
            best_shift_reg <= 0;
            temp_deviation <= 0;
            count_greater <= 0;
            count_less <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Unpack permutation on start
    always @(posedge clk) begin
        if (start && current_state == IDLE) begin
            for (int i = 0; i < 8; i = i + 1) begin
                p[i] <= p_in[(i+1)*8-1 : i*8];
            end
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
            end
            INIT: begin
                next_state = ITERATE;
            end
            ITERATE: begin
                if (shift_count == 7) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Initial deviation calculation (k=0)
    always @(posedge clk) begin
        if (current_state == INIT) begin
            current_deviation <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                current_deviation <= current_deviation + ($signed(p[i]) - $signed(i+1));
            end
            min_deviation_reg <= current_deviation;
            best_shift_reg <= 0;
            shift_count <= 1;
        end
    end

    // Incremental deviation calculation
    always @(posedge clk) begin
        if (current_state == ITERATE) begin
            // Calculate count_greater and count_less
            count_greater <= 0;
            count_less <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                if (p[i] > (i+1)) count_greater <= count_greater + 1;
                else if (p[i] < (i+1)) count_less <= count_less + 1;
            end

            // Calculate new deviation
            temp_deviation <= current_deviation + ($signed(p[8-shift_count]) - 8) - ($signed(count_greater) - $signed(count_less));

            // Update min deviation and best shift
            if ($signed(temp_deviation) < $signed(min_deviation_reg)) begin
                min_deviation_reg <= temp_deviation;
                best_shift_reg <= shift_count;
            end

            current_deviation <= temp_deviation;
            shift_count <= shift_count + 1;
        end
    end

    // Output results
    always @(posedge clk) begin
        if (current_state == DONE) begin
            min_deviation <= min_deviation_reg;
            best_shift <= best_shift_reg;
            done <= 1;
        end else begin
            done <= 0;
        end
    end

endmodule