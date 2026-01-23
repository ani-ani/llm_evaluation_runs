module doggo_standardization (
input reg clk,
input reg rst_n, // active-low reset
input reg start,
input reg [4:0] char_in,
input reg char_valid,
output reg result,
output reg done
);

localparam MAX_LEN = 16;
localparam CHAR_WIDTH =5;

localparam IDLE = 0,
RECV =1,
CHECK=2,
DONE=3;

reg [1:0] state_reg, state_next;
reg [3:0] recv_cnt;
reg [0:0] check_cnt;
reg [4:0] color_count [0:25];

reg [3:0] total_p;
reg result_temp;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        recv_cnt <=0;
        check_cnt <=0;
        for (int i=0; i<26; i++) color_count[i] <=0;
        result <=0;
        done <=0;
        result_temp <=0;
    end else begin
        state_reg <= state_next;

        if (state_reg == RECV) begin
            if (recv_cnt == MAX_LEN -1) begin
                state_next = CHECK;
                recv_cnt <= MAX_LEN;
            end else if (recv_cnt < MAX_LEN) begin
                recv_cnt <= recv_cnt +1;
            end

            if (char_valid) begin
                int c = char_in;
                if (c >=0 && c <=25) // though input is 0-25
                    color_count[c] <= color_count[c] +1;
            end
        end else if (state_reg == CHECK) begin
            if (check_cnt ==0) begin
                // Compute has_any_ge2
                wire has_any_ge2 = 0;
                has_any_ge2 = (color_count[0] >=2) | (color_count[1] >=2);
                has_any_ge2 = has_any_ge2 | (color_count[2] >=2);
                // ... (abbreviated for brevity)

                // Compute total_p
                total_p = color_count[0];
                total_p = total_p + color_count[1];
                total_p = total_p + color_count[2];
                // ... (abbreviated)

                wire cond = (total_p ==1) || has_any_ge2;
                result_temp <= cond;
                check_cnt <=1;
            end else begin
                result <= result_temp;
                done <=1;
                state_next <= DONE;
            end
        end else if (state_reg == DONE) begin
            done <=1;
            state_next <= DONE;
        end

        // Transition from IDLE to RECV when start is high
        if (state_reg == IDLE) begin
            if (start ==1) begin
                state_next = RECV;
                // Initialize counters
                recv_cnt <=0;
                check_cnt <=0;
                for (int i=0; i<26; i++) color_count[i] <=0;
            end
        end
    end
endmodule
