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
    parameter SETTLE = 3'b100;
    parameter DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] receipt_count;
    reg [15:0] balances [0:MAX_PEOPLE-1];
    reg [2:0] pos_idx;
    reg [2:0] neg_idx;
    reg [15:0] transfer_amount;
    reg [7:0] transaction_count;
    reg [2:0] people_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            receipt_count <= 0;
            num_transactions <= 0;
            done <= 0;
            error <= 0;
            transaction_count <= 0;
            pos_idx <= 0;
            neg_idx <= 0;
            transfer_amount <= 0;
            people_count <= 0;
            for (int i = 0; i < MAX_PEOPLE; i = i + 1) begin
                balances[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        if (num_people == 0 || num_people > MAX_PEOPLE) begin
                            error <= 1;
                            state <= IDLE;
                        end else begin
                            error <= 0;
                            state <= RECEIPT_INPUT;
                            receipt_count <= 0;
                            people_count <= num_people;
                            for (int i = 0; i < MAX_PEOPLE; i = i + 1) begin
                                balances[i] <= 0;
                            end
                        end
                    end
                end
                RECEIPT_INPUT: begin
                    if (receipt_valid) begin
                        if (payer < people_count && beneficiary < people_count) begin
                            balances[payer] <= balances[payer] - amount;
                            balances[beneficiary] <= balances[beneficiary] + amount;
                            receipt_count <= receipt_count + 1;
                            if (receipt_count == num_receipts) begin
                                state <= CALC_BALANCES;
                            end
                        end else begin
                            error <= 1;
                            state <= IDLE;
                        end
                    end
                end
                CALC_BALANCES: begin
                    state <= SETTLE;
                    transaction_count <= 0;
                    pos_idx <= 0;
                    neg_idx <= 0;
                end
                SETTLE: begin
                    reg [15:0] max_pos;
                    reg [15:0] min_neg;
                    reg found_pos;
                    reg found_neg;
                    reg [2:0] temp_pos_idx;
                    reg [2:0] temp_neg_idx;

                    max_pos = 0;
                    min_neg = 0;
                    found_pos = 0;
                    found_neg = 0;
                    temp_pos_idx = 0;
                    temp_neg_idx = 0;

                    for (int i = 0; i < people_count; i = i + 1) begin
                        if (balances[i] > max_pos) begin
                            max_pos = balances[i];
                            temp_pos_idx = i;
                            found_pos = 1;
                        end
                        if (balances[i] < min_neg) begin
                            min_neg = balances[i];
                            temp_neg_idx = i;
                            found_neg = 1;
                        end
                    end

                    if (found_pos && found_neg) begin
                        if (max_pos > -min_neg) begin
                            transfer_amount = -min_neg;
                        end else begin
                            transfer_amount = max_pos;
                        end

                        balances[temp_pos_idx] = balances[temp_pos_idx] - transfer_amount;
                        balances[temp_neg_idx] = balances[temp_neg_idx] + transfer_amount;
                        transaction_count = transaction_count + 1;
                    end else begin
                        state <= DONE;
                        num_transactions <= transaction_count;
                        done <= 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        done <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule