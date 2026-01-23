module string_filter (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_in,
    input [127:0] filter_str,
    input [4:0] str_len,
    output reg [127:0] result,
    output reg [4:0] result_len,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT_LUT,
        PROCESSING,
        PACKING,
        DONE
    } state_t;

    state_t state, next_state;

    // LUT for filter characters (256 entries)
    reg [255:0] lut;

    // Output buffer (16 bytes)
    reg [7:0] out_buf [0:15];

    // Counters
    reg [3:0] init_idx;
    reg [3:0] proc_idx;
    reg [3:0] out_idx;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 128'b0;
            result_len <= 5'b0;
            done <= 1'b0;
            init_idx <= 4'b0;
            proc_idx <= 4'b0;
            out_idx <= 4'b0;
            for (int i = 0; i < 256; i++) lut[i] <= 1'b0;
            for (int i = 0; i < 16; i++) out_buf[i] <= 8'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_LUT;
                end
            end

            INIT_LUT: begin
                // Initialize LUT from filter_str
                if (init_idx < str_len) begin
                    lut[filter_str[8*init_idx +: 8]] = 1'b1;
                    init_idx = init_idx + 1'b1;
                end else begin
                    next_state = PROCESSING;
                    init_idx = 4'b0;
                end
            end

            PROCESSING: begin
                // Process str_in characters
                if (proc_idx < str_len) begin
                    reg [7:0] current_char = str_in[8*proc_idx +: 8];
                    if (!lut[current_char]) begin
                        out_buf[out_idx] = current_char;
                        out_idx = out_idx + 1'b1;
                    end
                    proc_idx = proc_idx + 1'b1;
                end else begin
                    next_state = PACKING;
                    proc_idx = 4'b0;
                end
            end

            PACKING: begin
                // Pack output buffer into result
                result = 128'b0;
                for (int i = 0; i < out_idx; i++) begin
                    result[8*i +: 8] = out_buf[i];
                end
                result_len = out_idx;
                next_state = DONE;
            end

            DONE: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule