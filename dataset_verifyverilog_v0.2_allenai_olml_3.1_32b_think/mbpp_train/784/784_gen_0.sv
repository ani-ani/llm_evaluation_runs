module mul_even_odd (input clk, input rst_n, // active low, input start, input [7:0][15:0] data_in, output reg [15:0] result, output reg done);

// Internal registers
reg [2:0] state; // 3 bits: IDLE(0), SCAN(1), COMPUTE(2), WAIT(3), DONE(4)
reg [2:0] scan_counter; // 0 to7, 3 bits
reg [15:0] first_even, first_odd;
reg [15:0] result_reg;
reg [1:0] wait_counter; // 2 bits for 0-3
reg done_flag;

// Next state register
reg [2:0] next_state;

// Combinational assignments
assign result = done_flag ? result_reg : 16'h0;
assign done = done_flag;

// Reset logic and state machine
always @(posedge clk) begin
    if (!rst_n) begin
        // Reset all registers
        state <= 0;
        scan_counter <=0;
        first_even <= 16'hFFFF;
        first_odd <= 16'hFFFF;
        result_reg <=0;
        wait_counter <=0;
        done_flag <=0;
        next_state <=0;
    end else begin
        // Compute next state and register values
        next_state = state; // default to current state

        // Case statement for state transitions and updates
        case (state)
            0: begin
                if (start)
                    next_state =1;
            end
            1: begin
                // Process current element
                if (data_in[scan_counter] & 1 ==0) begin // even
                    if (first_even == 16'hFFFF)
                        first_even <= data_in[scan_counter];
                end else begin // odd
                    if (first_odd == 16'hFFFF)
                        first_odd <= data_in[scan_counter];
                end
                if (scan_counter <7) begin
                    scan_counter <= scan_counter +1;
                    next_state =1;
                end else begin
                    next_state =2;
                end
            end
            2: begin
                // Determine result_reg
                if (first_even ==16'hFFFF || first_odd ==16'hFFFF) begin
                    result_reg <=16'hFFFF;
                end else begin
                    result_reg <= (first_even * first_odd) & 16'hFFFF;
                end
                // Move to WAIT state with wait_counter=3
                next_state =3;
                wait_counter <=3;
            end
            3: begin
                if (wait_counter >0) begin
                    wait_counter <= wait_counter -1;
                    next_state =3;
                end else begin
                    next_state =4;
                    done_flag <=1;
                end
            end
            4: begin
                // No action, stay in DONE
            end
        endcase

        // Update state register
        state <= next_state;

        // Note: other registers (first_even, etc.) are updated via non-blocking assignments inside the case.
    end
endmodule