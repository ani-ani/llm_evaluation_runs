module slime_merge(
    input clk,
    input rst_n,
    input start,
    input [16:0] n_in,
    output reg [4:0] result_v [0:16],
    output reg [4:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Register declarations
    reg [1:0] state, next_state;
    reg [16:0] counter;
    reg [4:0] bit_position;
    reg [4:0] write_index;
    reg [4:0] read_index;
    reg [4:0] temp_result_v [0:16];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            counter <= 17'd0;
            bit_position <= 5'd0;
            write_index <= 5'd0;
            read_index <= 5'd0;
            result_len <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize result_v array
            integer i;
            for (i = 0; i < 17; i = i + 1) begin
                result_v[i] <= 5'd0;
                temp_result_v[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESSING;
                        counter <= n_in;
                        bit_position <= 5'd0;
                        write_index <= 5'd0;
                        read_index <= 5'd0;
                        result_len <= 5'd0;

                        // Clear temp array
                        integer i;
                        for (i = 0; i < 17; i = i + 1) begin
                            temp_result_v[i] <= 5'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    if (counter > 17'd0) begin
                        if (counter[0]) begin
                            temp_result_v[write_index] <= bit_position + 5'd1;
                            write_index <= write_index + 5'd1;
                        end
                        counter <= counter >> 1;
                        bit_position <= bit_position + 5'd1;
                        next_state <= PROCESSING;
                    end else begin
                        result_len <= write_index;
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (read_index < result_len) begin
                        result_v[read_index] <= temp_result_v[result_len - 5'd1 - read_index];
                        read_index <= read_index + 5'd1;
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule