module move_zero (
input clk,
input rst_n,
input start,
input [3:0] num_elements,
input [15:0] input_array [15:0],
output reg [15:0] output_array [15:0],
output reg done
);

parameter IDLE = 2'd0,
PASS1_COUNT = 2'd1,
PASS1_EXTRACT = 2'd2,
PASS2_FILL = 2'd3,
DONE = 2'd4;

reg [1:1] state_reg;

reg [15:0] count;
reg [15:0] temp_buf [15:0];
reg [3:0] temp_idx;
reg [3:0] pass1_timer;
reg [3:0] pass2_timer;
reg [2:0] done_timer;
reg [3:0] idx;

always @(*) begin
    if (state_reg == PASS1_EXTRACT || state_reg == DONE) begin
        for (int i=0; i<16; i++) begin
            if (i < count) begin
                output_array[i] = temp_buf[i];
            end else begin
                output_array[i] = 0;
            end
        end
    end else begin
        output_array = 0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        count <=0;
        temp_idx <=0;
        pass1_timer <=0;
        pass2_timer <=0;
        done_timer <=0;
        idx <=0;
        done <=0;
    end else begin
        if (state_reg == IDLE) begin
            if (start) begin
                state_reg <= PASS1_COUNT;
                pass1_timer <=16;
                idx <=0;
            end
        end

        else if (state_reg == PASS1_COUNT) begin
            if (pass1_timer >0) begin
                pass1_timer <= pass1_timer -1;

                if (idx < num_elements) begin
                    if (input_array[idx] !=0) begin
                        temp_buf[temp_idx] = input_array[idx];
                        temp_idx <= temp_idx +1;
                    end
                end

                idx <= idx +1;

            end

            if (pass1_timer ==0) begin
                state_reg <= PASS1_EXTRACT;
                count <= temp_idx;

            end

        end

        else if (state_reg == PASS1_EXTRACT) begin

            pass2_timer <=16;

            if (1) begin
                state_reg <= PASS2_FILL;

            end

        end

        else if (state_reg == PASS2_FILL) begin

            if (pass2_timer >0) begin
                pass2_timer <= pass2_timer -1;

            end else begin

                state_reg <= DONE;

                done_timer <=4;

                pass2_timer <=0;

            end

        end

        else if (state_reg == DONE) begin

            if (done_timer >0) begin
                done_timer <= done_timer -1;

            end else begin

                done <=1;

            end

        end

    end

endmodule