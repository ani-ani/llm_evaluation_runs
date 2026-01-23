module zebra_max (
    input clk,
    input rst_n,
    input start,
    input [3:0] actual_length,
    input [15:0] string_in,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] NEXT = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [4:0] i;
    reg [3:0] idx;
    reg [4:0] run_reg;
    reg [4:0] max_run_reg;
    reg prev_char;
    reg [15:0] string_storage;
    reg [3:0] n;
    
    // Combinational logic
    wire [3:0] next_idx = (idx == n - 1) ? 0 : idx + 1;
    wire next_char = string_storage[next_idx];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            i <= 5'd0;
            idx <= 4'd0;
            run_reg <= 5'd0;
            max_run_reg <= 5'd0;
            prev_char <= 1'b0;
            string_storage <= 16'd0;
            n <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (actual_length == 4'd0) begin
                            result <= 5'd0;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            n <= actual_length;
                            string_storage <= string_in;
                            i <= 5'd0;
                            idx <= 4'd0;
                            run_reg <= 5'd1;
                            max_run_reg <= 5'd1;
                            prev_char <= string_in[0];
                            state <= NEXT;
                        end
                    end
                end
                
                NEXT: begin
                    if (next_char != prev_char) begin
                        if (run_reg < n)
                            run_reg <= run_reg + 5'd1;
                        else
                            run_reg <= n;
                        if (run_reg + 5'd1 > max_run_reg)
                            max_run_reg <= run_reg + 5'd1;
                    end else begin
                        run_reg <= 5'd1;
                    end
                    
                    prev_char <= next_char;
                    idx <= next_idx;
                    i <= i + 5'd1;
                    
                    if (i == 2*n - 2)
                        state <= DONE;
                end
                
                DONE: begin
                    result <= (max_run_reg > n) ? n : max_run_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule