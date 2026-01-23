module optimal_probability (input clk, input rst_n, // active low input start, input [4:0] n, // not used in this implementation input [7:0] p_in, output reg [31:0] result, output reg done);

    // Internal registers
    reg [1:0] state;
    reg [7:0] max_val;
    reg [3:0] down_count; // for 8 counts (4 bits)
    reg [1:0] proc_count; // for 2 cycles

    // Combinational assignments
    assign result = (max_val << 8); // Q16.16
    assign done = (state == 2'b11);

    // Clock and reset
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= 2'b00;
            max_val <= 8'b0;
            down_count <= 4'd8;
            proc_count <= 2'b0;
        end else begin
            case (state)
                2'b00: // IDLE
                    if (start) begin
                        state <= 2'b01;
                        max_val <= 8'b0;
                        down_count <= 4'd8;
                    end else begin
                        state <= 2'b00;
                    end
                2'b01: // INPUT
                    if (down_count > 0) begin
                        down_count <= down_count - 1;
                        if (p_in > max_val) begin
                            max_val <= p_in;
                        end
                    end else begin
                        state <= 2'b10;
                        proc_count <= 2'b10;
                    end
                2'b10: // PROCESS
                    if (proc_count > 0) begin
                        proc_count <= proc_count - 1;
                    end else begin
                        state <= 2'b11;
                    end
                2'b11: // DONE
                    state <= 2'b11;
            endcase
        end
    end
endmodule