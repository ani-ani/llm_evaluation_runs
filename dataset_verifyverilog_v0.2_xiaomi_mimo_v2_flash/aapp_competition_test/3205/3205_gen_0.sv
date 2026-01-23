module settle_bills (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_people,
    input [2:0] num_receipts,
    input [2:0] payer,
    input [2:0] beneficiary,
    input [15:0] amount,
    input receipt_valid,
    output reg [7:0] num_transactions,
    output reg done,
    output reg error
);

    parameter MAX_PEOPLE = 8;
    parameter IDLE = 3'b000;
    parameter RECEIPT_INPUT = 3'b001;
    parameter CALC_BALANCES = 3'b010;
    parameter SETTLE = 3'b011;
    parameter DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] receipt_count;
    reg [2:0] receipts_to_process;
    reg signed [15:0] balances [0:7];
    reg [2:0] p_pos;
    reg [2:0] p_neg;
    reg signed [15:0] transfer_amt;
    reg [2:0] settle_idx;
    reg processing_started;

    integer i;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && !processing_started) next_state = RECEIPT_INPUT;
                else next_state = IDLE;
            end
            RECEIPT_INPUT: begin
                if (receipt_count >= receipts_to_process) next_state = CALC_BALANCES;
                else next_state = RECEIPT_INPUT;
            end
            CALC_BALANCES: begin
                next_state = SETTLE;
            end
            SETTLE: begin
                if (p_pos == num_people || p_neg == num_people) next_state = DONE;
                else next_state = SETTLE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_transactions <= 8'b0;
            done <= 1'b0;
            error <= 1'b0;
            receipt_count <= 3'b0;
            receipts_to_process <= 3'b0;
            p_pos <= 3'b0;
            p_neg <= 3'b0;
            settle_idx <= 3'b0;
            processing_started <= 1'b0;
            for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
                balances[i] <= 16'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start && !processing_started) begin
                        receipt_count <= 3'b0;
                        num_transactions <= 8'b0;
                        p_pos <= 3'b0;
                        p_neg <= 3'b0;
                        settle_idx <= 3'b0;
                        processing_started <= 1'b1;
                        if (num_people > 3'd0 && num_people <= 3'd8 && num_receipts <= 3'd8) begin
                            receipts_to_process <= num_receipts;
                            error <= 1'b0;
                            for (i = 0; i < MAX_PEOPLE; i = i + 1) begin
                                balances[i] <= 16'sd0;
                            end
                        end else begin
                            error <= 1'b1;
                            // Prevent entering receipt input by forcing count to match immediately in next cycle logic below
                            receipts_to_process <= 3'b0; // Skip receipt phase immediately if invalid on start
                            // However, to strictly follow state machine, we might need error logic. For simplicity, we rely on state transition which checks receipt_count >= receipts_to_process
                        end
                    end else begin
                        processing_started <= 1'b0;
                    end
                end

                RECEIPT_INPUT: begin
                    if (receipt_valid) begin
                        // Check if payer and beneficiary are valid indices < num_people
                        if (payer < num_people && beneficiary < num_people) begin
                            // Add balance: Payer -Amount (paid for someone), Beneficiary +Amount (received)
                            balances[payer] <= balances[payer] - {1'b0, amount}; // Assuming amount is positive, cast to signed
                            balances[beneficiary] <= balances[beneficiary] + {1'b0, amount};
                            receipt_count <= receipt_count + 1'b1;
                        end else begin
                            // Invalid receipt data, set error, skip this receipt? Or stop.
                            // For robustness, we count it as processed to avoid infinite loop but set error.
                            error <= 1'b1;
                            receipt_count <= receipt_count + 1'b1;
                        end
                    end
                end

                CALC_BALANCES: begin
                    // No op, balances computed in previous state
                    // Logic to find first p_pos and p_neg starts here implicitly by p_pos/p_neg being 0 in SETTLE state
                    // Note: We need to find initial positive and negative balances here
                    // But since SETTLE is combinational logic relative to p_pos/p_neg, we might do the search in SETTLE or PREP state.
                    // To save latency, let's do search in SETTLE state logic if p_pos/p_neg are pointers.
                    // However, standard sequential approach: We initialize pointers here or in IDLE.
                    // Let's make SETTLE state handle the iteration.
                    // If we are in CALC_BALANCES, we prepare to enter SETTLE.
                    p_pos <= 3'b0;
                    p_neg <= 3'b0;
                end

                SETTLE: begin
                    // Check if pointers reached end
                    if (p_pos < num_people && p_neg < num_people) begin
                        // Find next positive balance
                        if (balances[p_pos] <= 16'sd0) begin
                            p_pos <= p_pos + 1'b1;
                        end
                        // Find next negative balance
                        else if (balances[p_neg] >= 16'sd0) begin
                            p_neg <= p_neg + 1'b1;
                        end
                        // Found valid pair
                        else begin
                            // Determine transfer amount
                            if (balances[p_pos] < -balances[p_neg]) begin
                                transfer_amt <= balances[p_pos];
                                // Update balances
                                balances[p_neg] <= balances[p_neg] + transfer_amt; // p_neg is negative, adding negative amount = subtracting absolute
                                balances[p_pos] <= 16'sd0;
                            end else begin
                                transfer_amt <= -balances[p_neg];
                                balances[p_pos] <= balances[p_pos] + transfer_amt; // p_pos is positive, adding positive
                                balances[p_neg] <= 16'sd0;
                            end
                            num_transactions <= num_transactions + 1'b1;
                            // Do not increment pointers here immediately; next cycle they will be 0 (since we set balance to 0) and loop will increment them.
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for start to go low to reset processing_started
                    if (!start) begin
                        processing_started <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
