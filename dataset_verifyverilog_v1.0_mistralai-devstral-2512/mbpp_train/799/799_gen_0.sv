module left_rotate_32(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] num_in,
    input wire [4:0] d_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;

    reg [1:0] state;
    reg [31:0] shifted_left;
    reg [31:0] shifted_right;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            shifted_left <= 32'd0;
            shifted_right <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Calculate left and right shifts
                    shifted_left <= num_in << d_in;
                    shifted_right <= num_in >> (32 - d_in);
                    
                    // Combine for rotation
                    result <= shifted_left | shifted_right;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule