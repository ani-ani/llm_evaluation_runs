module gon_probability_generic #(
    parameter MAX_STATES = 16,
    parameter STATE_BITS = 4,
    parameter ITERATIONS = 256
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p,
    input wire [3:0] num_states,
    input wire [3:0] next_H [0:MAX_STATES-1],
    input wire [3:0] next_T [0:MAX_STATES-1],
    output reg [31:0] result,
    output reg done
);

    localparam [31:0] ONE = 32'h00010000;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [31:0] state_val [0:MAX_STATES-1];
    reg [31:0] new_val [0:MAX_STATES-1];
    reg [STATE_BITS-1:0] idx;
    reg [7:0] iter;
    reg [31:0] p_inv;
    
    function automatic [31:0] mul;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] tmp;
        begin
            tmp = a * b;
            mul = tmp[47:16];
        end
    endfunction

    function automatic [31:0] next_val;
        input [3:0] nxt;
        begin
            case (nxt)
                4'd8:  next_val = ONE;
                4'd9:  next_val = 32'd0;
                4'd10: next_val = 32'd0;
                default: next_val = state_val[nxt];
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            iter <= 8'd0;
            idx <= {STATE_BITS{1'b0}};
            p_inv <= 32'd0;
            for (integer i=0; i<MAX_STATES; i=i+1) begin
                state_val[i] <= 32'd0;
                new_val[i] <= 32'd0;
            end
        end else begin
            p_inv <= ONE - p;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (integer i=0; i<MAX_STATES; i=i+1)
                            state_val[i] <= 32'd0;
                        state <= COMPUTE;
                        iter <= 8'd0;
                        idx <= {STATE_BITS{1'b0}};
                    end
                end
                
                COMPUTE: begin
                    if (idx < num_states) begin
                        new_val[idx] <= mul(p, next_val(next_H[idx])) + mul(p_inv, next_val(next_T[idx]));
                        idx <= idx + 1;
                    end else begin
                        for (integer i=0; i<MAX_STATES; i=i+1)
                            state_val[i] <= new_val[i];
                        idx <= {STATE_BITS{1'b0}};
                        iter <= iter + 8'd1;
                        if (iter >= (ITERATIONS-1))
                            state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= state_val[0];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule