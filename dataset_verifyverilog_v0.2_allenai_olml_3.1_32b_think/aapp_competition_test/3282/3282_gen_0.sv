module dessert_finder (input clk, input rst_n, // active-low reset, input start, input [8:0] P, output reg valid, output reg [8:0] B_out, output reg [8:0] M_out, output reg done, output reg [6:0] count);

// Internal signals
reg [7:0] state; // IDLE=0, COMPUTE=1, OUTPUT=2, DONE=3
reg [7:0] b_counter;
reg [2:0] delay_counter; // 0 to 3, 4 cycles per B
reg [31:0] total_count;
reg [17:0] fifo [0:63]; // 64 entries, each 18 bits (B and M)
reg [4:0] fifo_wptr, fifo_rptr, fifo_count;

// State machine logic
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        b_counter <= 0;
        delay_counter <=0;
        total_count <=0;
        fifo_wptr <=0;
        fifo_rptr <=0;
        fifo_count <=0;
        // Reset FIFO by assigning all to 0 (non-synthesizable)
        for (int i=0; i<64; i=i+1) begin
            fifo[i] <= 0;
        end
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= 1; // COMPUTE
                    b_counter <=1;
                    delay_counter <=0;
                    total_count <=0;
                    fifo_wptr <=0;
                    fifo_rptr <=0;
                    fifo_count <=0;
                end
            end
            COMPUTE: begin
                if (delay_counter ==0) begin
                    int M_val = P - b_counter;
                    if (2*b_counter < P) begin
                        if (fifo_count <64) begin
                            fifo[fifo_wptr] = {b_counter, M_val};
                            fifo_wptr = fifo_wptr +1;
                            if (fifo_wptr ==64) fifo_wptr <=0;
                            fifo_count = fifo_count +1;
                            total_count = total_count +1;
                        end
                    end
                end
                if (delay_counter <3) begin
                    delay_counter <= delay_counter +1;
                end else begin
                    if (b_counter <255) begin
                        b_counter <= b_counter +1;
                        delay_counter <=0;
                    end else begin
                        state <= 2; // OUTPUT
                        delay_counter <=0;
                        b_counter <=0;
                    end
                end
            end
            OUTPUT: begin
                if (fifo_rptr < fifo_wptr || fifo_count >0) begin
                    B_out = fifo[fifo_rptr][8:0];
                    M_out = fifo[fifo_rptr][17:9]; 
                    valid =1;
                    fifo_rptr = fifo_rptr +1;
                    if (fifo_rptr ==64) fifo_rptr <=0;
                    if (fifo_rptr == fifo_wptr && fifo_count ==0) begin
                        state <= 3; // DONE
                    end
                end else begin
                    state <= 3;
                end
            end
            DONE: begin
                done =1;
                valid =0;
                B_out =0;
                M_out =0;
            end
        endcase
    end
endmodule