module numeric_string_sorter(
    input  clk,
    input  rst_n,
    input  start,
    input  signed [11:0] numbers [7:0],
    output reg signed [11:0] sorted [7:0],
    output reg done
);

    // FSM state encoding
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        COMPARE = 2'b01,
        SWAP    = 2'b10,
        DONE    = 2'b11
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg signed [11:0] work [7:0];
    reg [2:0] i;           // outer loop index (0..6)
    reg [2:0] j;           // inner loop index (0..6)
    reg       swap_req;    // indicates swap needed between work[j] and work[j+1]

    integer idx;

    // FSM sequential logic and datapath updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            done    <= 1'b0;
            i       <= 3'd0;
            j       <= 3'd0;
            swap_req <= 1'b0;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                work[idx]   <= '0;
                sorted[idx] <= '0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input numbers into working array at start
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            work[idx] <= numbers[idx];
                        end
                        i        <= 3'd0;
                        j        <= 3'd0;
                        swap_req <= 1'b0;
                    end
                end

                COMPARE: begin
                    // Evaluate comparison for current pair (j, j+1)
                    if (work[j] > work[j+1])
                        swap_req <= 1'b1;
                    else
                        swap_req <= 1'b0;
                end

                SWAP: begin
                    // Conditionally swap based on previous comparison
                    if (swap_req) begin
                        reg signed [11:0] temp;
                        temp        <= work[j];
                        work[j]     <= work[j+1];
                        work[j+1]   <= temp;
                    end

                    // Update indices for next comparison
                    if (j + 1 < 7 - i) begin
                        j <= j + 1'b1;
                    end else begin
                        j <= 3'd0;
                        if (i < 3'd6)
                            i <= i + 1'b1;
                        else
                            i <= i; // complete
                    end
                end

                DONE: begin
                    // Latch sorted result and assert done
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        sorted[idx] <= work[idx];
                    end
                    done <= 1'b1;
                end

                default: begin
                    // Safety default
                    done <= 1'b0;
                end
            endcase
        end
    end

    // FSM next-state combinational logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPARE;
                else
                    next_state = IDLE;
            end

            COMPARE: begin
                next_state = SWAP;
            end

            SWAP: begin
                // Decide whether to continue or finish based on indices
                if ((i == 3'd6) && (j + 1 >= 7 - i))
                    next_state = DONE;
                else
                    next_state = COMPARE;
            end

            DONE: begin
                // Wait here until start is deasserted; then go back to IDLE
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule