module bracket_fixer (
    input clk,
    input rst_n,
    input start,
    input [15:0] seq,        // Each bit: 0 for '(', 1 for ')'
    input [4:0] valid_length, // 0 to 16
    output reg result,
    output reg done
);

parameter MAX_N = 16;

// State definitions
localparam IDLE = 2'b00;
localparam PROCESS = 2'b01;
localparam DONE = 2'b10;

reg [1:0] state;
reg [4:0] counter;
reg signed [7:0] current_balance;
reg signed [7:0] min_balance;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 4'd0;
        current_balance <= 8'sd0;
        min_balance <= 8'sd0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    counter <= 4'd0;
                    current_balance <= 8'sd0;
                    min_balance <= 8'sd0;
                    if (valid_length == 5'd0)
                        state <= DONE;
                    else
                        state <= PROCESS;
                end
            end

            PROCESS: begin
                // Process current bracket
                if (seq[counter] == 1'b0) begin // '('
                    current_balance <= current_balance + 8'sd1;
                    if (min_balance < (current_balance + 8'sd1)) begin
                        min_balance <= min_balance;
                    end else begin
                        min_balance <= current_balance + 8'sd1;
                    end
                end else begin // ')'
                    current_balance <= current_balance - 8'sd1;
                    if (min_balance < (current_balance - 8'sd1)) begin
                        min_balance <= min_balance;
                    end else begin
                        min_balance <= current_balance - 8'sd1;
                    end
                end

                counter <= counter + 4'd1;

                if (counter + 4'd1 == valid_length)
                    state <= DONE;
            end

            DONE: begin
                result <= (current_balance == 8'sd0) && (min_balance >= -8'sd1);
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule