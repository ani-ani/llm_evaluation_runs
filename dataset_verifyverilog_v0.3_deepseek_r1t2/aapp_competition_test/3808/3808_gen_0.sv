module bracket_fixer (
    input clk,
    input rst_n,
    input start,
    input [15:0] seq,
    input [4:0] valid_length,
    output reg result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [4:0] counter;
    reg signed [7:0] current_balance;
    reg signed [7:0] min_balance;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 5'd0;
            current_balance <= 8'd0;
            min_balance <= 8'd0;
            result <= 1'd0;
            done <= 1'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        counter <= 5'd0;
                        current_balance <= 8'd0;
                        min_balance <= 8'd0;
                        if (valid_length == 5'd0)
                            state <= DONE;
                        else
                            state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (seq[counter] == 1'b0) begin // '('
                        current_balance <= current_balance + 8'sd1;
                        if (min_balance > (current_balance + 8'sd1))
                            min_balance <= current_balance + 8'sd1;
                        else
                            min_balance <= min_balance;
                    end else begin // ')'
                        current_balance <= current_balance - 8'sd1;
                        if (min_balance > (current_balance - 8'sd1))
                            min_balance <= current_balance - 8'sd1;
                        else
                            min_balance <= min_balance;
                    end
                    counter <= counter + 5'd1;
                    if ((counter + 5'd1) == valid_length)
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