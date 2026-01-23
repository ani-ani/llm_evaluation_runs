module std_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg [7:0] count,
    output reg done,
    output reg error
);

    // Define states for main FSM
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    // Define states for 'std' detection FSM
    typedef enum logic [1:0] {
        S0_WAIT_S,
        S1_GOT_S,
        S2_GOT_ST
    } std_state_t;

    // State registers
    state_t state = IDLE;
    std_state_t std_state = S0_WAIT_S;

    // Character counter (0-32)
    reg [5:0] char_count = 0;

    // Process character when valid_in is high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            std_state <= S0_WAIT_S;
            count <= 0;
            done <= 0;
            error <= 0;
            char_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        std_state <= S0_WAIT_S;
                        count <= 0;
                        done <= 0;
                        error <= 0;
                        char_count <= 0;
                    end
                end

                PROCESSING: begin
                    if (!start) begin
                        state <= IDLE;
                    end else if (valid_in) begin
                        // Check for null terminator
                        if (char_in == 8'h00) begin
                            state <= DONE;
                            done <= 1;
                        end else begin
                            // Check character count limit
                            if (char_count == 32) begin
                                error <= 1;
                                state <= DONE;
                                done <= 1;
                            end else begin
                                char_count <= char_count + 1;

                                // 'std' detection FSM
                                case (std_state)
                                    S0_WAIT_S: begin
                                        if (char_in == 8'h73) begin // 's'
                                            std_state <= S1_GOT_S;
                                        end
                                    end

                                    S1_GOT_S: begin
                                        if (char_in == 8'h74) begin // 't'
                                            std_state <= S2_GOT_ST;
                                        end else begin
                                            std_state <= S0_WAIT_S;
                                        end
                                    end

                                    S2_GOT_ST: begin
                                        if (char_in == 8'h64) begin // 'd'
                                            count <= count + 1;
                                            std_state <= S0_WAIT_S;
                                        end else begin
                                            std_state <= S0_WAIT_S;
                                        end
                                    end

                                    default: std_state <= S0_WAIT_S;
                                endcase
                            end
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                        error <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule