module string_generator (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [4:0] k,
    output reg [1023:0] result,
    output reg [7:0] length_out,
    output reg valid,
    output reg error
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK,
        GEN_LOOP,
        FINISH,
        ERROR
    } state_t;

    state_t state;
    reg [7:0] i; // Loop counter
    reg [7:0] prefix_len;
    reg [7:0] remaining_len;
    reg [7:0] current_char;
    reg [7:0] next_char;
    reg [7:0] temp_result [0:127];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            prefix_len <= 0;
            remaining_len <= 0;
            current_char <= 0;
            next_char <= 0;
            result <= 0;
            length_out <= 0;
            valid <= 0;
            error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK;
                    end
                end
                CHECK: begin
                    if ((k > 26) || (k == 1 && n > 1) || (n < k)) begin
                        state <= ERROR;
                    end else begin
                        state <= GEN_LOOP;
                        i <= 0;
                        prefix_len <= n - (k - 2);
                        remaining_len <= (k - 2);
                        current_char <= "a";
                        next_char <= "b";
                    end
                end
                GEN_LOOP: begin
                    if (i < n) begin
                        if (i < prefix_len) begin
                            if (i % 2 == 0) begin
                                temp_result[i] <= "a";
                            end else begin
                                temp_result[i] <= "b";
                            end
                        end else begin
                            temp_result[i] <= "a" + (i - prefix_len + 2);
                        end
                        i <= i + 1;
                    end else begin
                        state <= FINISH;
                    end
                end
                FINISH: begin
                    valid <= 1;
                    error <= 0;
                    // Pack the result
                    for (int j = 0; j < 128; j = j + 1) begin
                        if (j < n) begin
                            result[(j+1)*8-1:j*8] <= temp_result[j];
                        end else begin
                            result[(j+1)*8-1:j*8] <= 0;
                        end
                    end
                    length_out <= n;
                end
                ERROR: begin
                    error <= 1;
                    valid <= 0;
                    result <= 0;
                    length_out <= 0;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule