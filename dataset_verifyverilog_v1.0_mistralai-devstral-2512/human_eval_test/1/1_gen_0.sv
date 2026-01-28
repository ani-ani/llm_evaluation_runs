module paren_parser(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_end,
    output reg group_start,
    output reg group_end,
    output reg done,
    output reg [15:0] result
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] READING = 2'd1;
    localparam [1:0] ERROR   = 2'd2;

    reg [1:0] state;
    reg [4:0] balance;  // 5-bit counter
    reg [3:0] group_count;
    reg [3:0] max_balance;
    reg [7:0] char_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 5'd0;
            group_count <= 4'd0;
            max_balance <= 4'd0;
            group_start <= 1'b0;
            group_end <= 1'b0;
            done <= 1'b0;
            result <= 16'd0;
            char_prev <= 8'd0;
        end else begin
            group_start <= 1'b0;
            group_end <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READING;
                        balance <= 5'd0;
                        group_count <= 4'd0;
                        max_balance <= 4'd0;
                    end
                end

                READING: begin
                    if (char_valid) begin
                        if (char_in == 8'h20) begin
                            // Ignore spaces
                        end else if (char_in == 8'h28) begin
                            // '(' character
                            balance <= balance + 5'd1;
                            if (balance > max_balance) begin
                                max_balance <= balance;
                            end
                            if (char_prev == 8'h29 && balance == 5'd1) begin
                                group_start <= 1'b1;
                            end
                        end else if (char_in == 8'h29) begin
                            // ')' character
                            balance <= balance - 5'd1;
                            if (balance == 5'd0) begin
                                group_end <= 1'b1;
                                group_count <= group_count + 4'd1;
                            end
                        end
                        char_prev <= char_in;
                    end

                    if (char_end) begin
                        if (balance == 5'd0) begin
                            done <= 1'b1;
                            result <= {max_balance, group_count};
                            state <= IDLE;
                        end else begin
                            state <= ERROR;
                        end
                    end
                end

                ERROR: begin
                    if (start) begin
                        state <= READING;
                        balance <= 5'd0;
                        group_count <= 4'd0;
                        max_balance <= 4'd0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule