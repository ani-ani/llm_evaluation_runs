module bracket_eval (
    input clk,
    input rst_n,
    input start,
    input [7:0] token_in,
    input token_valid,
    input token_end,
    output reg [31:0] result,
    output reg result_valid,
    output reg done
);

localparam MOD = 32'h3B9ACA07;
localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;
localparam PAR_OPEN = 8'h28;
localparam PAR_CLOSE = 8'h29;

reg [1:0] state;
reg [2:0] stack_depth;
reg [31:0] current_value;
reg [0:0] current_mode;
reg [31:0] stack_values [7:0];
reg [0:0] stack_modes [7:0];
reg [7:0] token_reg;
reg start_pulse;

assign result_valid = done;
assign done = (state == DONE);

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        stack_depth <=0;
        current_value <=0;
        current_mode <=0;
        for (int i=0; i<8; i++) begin
            stack_values[i] <=0;
            stack_modes[i] <=0;
        end
        token_reg <=0;
        start_pulse <=0;
        result <=0;
    end else begin
        if (start_pulse) begin
            state <= PROCESSING;
            stack_depth <=0;
            current_value <=0;
            current_mode <=0;
            for (int i=0; i<8; i++) begin
                stack_values[i] <=0;
                stack_modes[i] <=0;
            end
            token_reg <=0;
        end

        if (state == IDLE && start ==1 && !start_pulse) begin
            start_pulse <=1;
        end else begin
            start_pulse <=0;
        end

        if (state == PROCESSING) begin
            if (token_valid) begin
                token_reg <= token_in;

                if (token_reg == PAR_OPEN) begin
                    if (stack_depth <8) begin
                        stack_values[stack_depth] <= current_value;
                        stack_modes[stack_depth] <= current_mode;
                        stack_depth <= stack_depth +1;
                    end
                    current_mode <= (stack_depth +1) %2;
                    if ( (stack_depth +1) %2 ==1 ) begin
                        current_value <=1;
                    end else begin
                        current_value <=0;
                    end
                end else if (token_reg == PAR_CLOSE) begin
                    if (stack_depth >0) begin
                        int temp = current_value;
                        stack_depth <= stack_depth -1;
                        current_value <= stack_values[stack_depth];
                        current_mode <= stack_modes[stack_depth];
                        if (current_mode ==1) begin
                            current_value <= (current_value * temp) % MOD;
                        end else begin
                            current_value <= (current_value + temp) % MOD;
                        end
                    end
                end else begin
                    int num = token_reg;
                    if (current_mode ==1) begin
                        current_value <= (current_value * num) % MOD;
                    end else begin
                        current_value <= (current_value + num) % MOD;
                    end
                end

                if (token_end) begin
                    state <= DONE;
                end else begin
                    state <= PROCESSING;
                end
            end else begin
                state <= PROCESSING;
            end
        end else if (state == DONE) begin
            result <= current_value;
        end
    end
endmodule