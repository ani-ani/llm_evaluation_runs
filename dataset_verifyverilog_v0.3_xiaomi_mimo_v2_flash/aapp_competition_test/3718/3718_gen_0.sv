module ball_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n,           // Number of balls (3-8)
    input wire [63:0] sizes_flat, // 8x8-bit sizes packed [63:0]
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CLEAR = 3'd1;
    localparam [2:0] MARK = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers
    reg [256:1] present;          // Present array (1-256)
    reg [5:0] n_reg;              // Stored n
    reg [63:0] sizes_flat_reg;    // Stored sizes
    reg [2:0] state;              // State machine
    reg [2:0] i;                  // Index counter (0-7)
    reg [7:0] current_size;       // Current size being processed

    // Combinational check for three consecutive sizes
    wire any_three;
    wire [256:1] present_shifted1;
    wire [256:1] present_shifted2;
    assign present_shifted1 = {1'b0, present[256:2]};
    assign present_shifted2 = {2'b0, present[256:3]};
    assign any_three = |(present[1:254] & present_shifted1[1:254] & present_shifted2[1:254]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            present <= 256'd0;
            n_reg <= 6'd0;
            sizes_flat_reg <= 64'd0;
            i <= 3'd0;
            current_size <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        sizes_flat_reg <= sizes_flat;
                        state <= CLEAR;
                    end
                end

                CLEAR: begin
                    present <= 256'd0;
                    i <= 3'd0;
                    state <= MARK;
                end

                MARK: begin
                    if (i < n_reg && i < 4'd8) begin
                        // Extract current size (8-bit from flattened array)
                        current_size <= sizes_flat_reg[8*i +: 8];
                        // Only mark valid sizes (1-255)
                        if (sizes_flat_reg[8*i +: 8] >= 8'd1 && 
                            sizes_flat_reg[8*i +: 8] <= 8'd255) begin
                            present[sizes_flat_reg[8*i +: 8]] <= 1'b1;
                        end
                        i <= i + 3'd1;
                    end else begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    result <= any_three;
                    done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule