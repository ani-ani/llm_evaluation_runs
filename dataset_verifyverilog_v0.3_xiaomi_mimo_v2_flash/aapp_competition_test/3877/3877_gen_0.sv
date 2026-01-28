module count_ones (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] l,
    input [7:0] r,
    output reg [15:0] count,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] DONE = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] n_reg, l_reg, r_reg, current_i;
    reg [3:0] msb_index;
    reg [3:0] ctz;
    reg [3:0] pos;
    reg bit;
    reg [7:0] i;

    // Find msb index of n (0-based from LSB)
    always @(*) begin
        msb_index = 4'd0;
        if (n[7]) msb_index = 4'd7;
        else if (n[6]) msb_index = 4'd6;
        else if (n[5]) msb_index = 4'd5;
        else if (n[4]) msb_index = 4'd4;
        else if (n[3]) msb_index = 4'd3;
        else if (n[2]) msb_index = 4'd2;
        else if (n[1]) msb_index = 4'd1;
        else if (n[0]) msb_index = 4'd0;
        // for n==0, msb_index remains 0
    end

    // Compute number of trailing zeros for current_i
    always @(*) begin
        ctz = 4'd0;
        if (current_i[0]) ctz = 4'd0;
        else if (current_i[1]) ctz = 4'd1;
        else if (current_i[2]) ctz = 4'd2;
        else if (current_i[3]) ctz = 4'd3;
        else if (current_i[4]) ctz = 4'd4;
        else if (current_i[5]) ctz = 4'd5;
        else if (current_i[6]) ctz = 4'd6;
        else if (current_i[7]) ctz = 4'd7;
    end

    // Compute pos and bit
    always @(*) begin
        if (msb_index >= ctz) begin
            pos = msb_index - ctz;
            bit = n_reg[pos];
        end else begin
            pos = 4'd0;
            bit = 1'b0;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && n == 8'd0) begin
                    next_state = DONE;
                end else if (start) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (current_i <= r_reg) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = DONE;
                end
            end
            COMPUTE: begin
                next_state = CHECK;
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count <= 16'd0;
            n_reg <= 8'd0;
            l_reg <= 8'd0;
            r_reg <= 8'd0;
            current_i <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        l_reg <= l;
                        r_reg <= r;
                        count <= 16'd0;
                        if (n == 8'd0) begin
                            // Will transition to DONE
                        end else begin
                            current_i <= l;
                        end
                    end
                end
                CHECK: begin
                    // Already evaluated next_state based on current_i
                end
                COMPUTE: begin
                    // Add bit if n!=0 (already ensured when entering COMPUTE)
                    count <= count + {15'd0, bit};
                    current_i <= current_i + 8'd1;
                end
                DONE: begin
                    done <= 1'b1;
                end
                default: begin
                    // Reset to known state
                end
            endcase
        end
    end

endmodule