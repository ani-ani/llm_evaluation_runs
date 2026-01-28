module hall_students (
    input clk,
    input rst_n,
    input start,
    input [7:0] num0, num1, num2, num3,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Function to compute gcd of two 8-bit numbers
    function automatic [7:0] gcd;
        input [7:0] a, b;
        reg [7:0] x, y;
        begin
            x = a; y = b;
            while (x != 0 && y != 0) begin
                if (x > y) x = x - y;
                else y = y - x;
            end
            gcd = x | y;
        end
    endfunction

    // Function to compute the count of valid trees
    function automatic [7:0] compute_count;
        input [7:0] n0, n1, n2, n3;
        reg [7:0] g01, g02, g03, g12, g13, g23;
        reg a01, a02, a03, a12, a13, a23;
        reg [5:0] allowed;
        reg [7:0] cnt;
        begin
            g01 = gcd(n0, n1);
            g02 = gcd(n0, n2);
            g03 = gcd(n0, n3);
            g12 = gcd(n1, n2);
            g13 = gcd(n1, n3);
            g23 = gcd(n2, n3);
            a01 = (g01 > 1);
            a02 = (g02 > 1);
            a03 = (g03 > 1);
            a12 = (g12 > 1);
            a13 = (g13 > 1);
            a23 = (g23 > 1);
            allowed = {a23, a13, a12, a03, a02, a01};
            cnt = 0;
            // Check each of the 12 non-crossing tree masks
            if ((allowed & 6'b000111) == 6'b000111) cnt = cnt + 1;
            if ((allowed & 6'b100011) == 6'b100011) cnt = cnt + 1;
            if ((allowed & 6'b001101) == 6'b001101) cnt = cnt + 1;
            if ((allowed & 6'b100101) == 6'b100101) cnt = cnt + 1;
            if ((allowed & 6'b011001) == 6'b011001) cnt = cnt + 1;
            if ((allowed & 6'b101001) == 6'b101001) cnt = cnt + 1;
            if ((allowed & 6'b110001) == 6'b110001) cnt = cnt + 1;
            if ((allowed & 6'b001110) == 6'b001110) cnt = cnt + 1;
            if ((allowed & 6'b101010) == 6'b101010) cnt = cnt + 1;
            if ((allowed & 6'b011100) == 6'b011100) cnt = cnt + 1;
            if ((allowed & 6'b101100) == 6'b101100) cnt = cnt + 1;
            if ((allowed & 6'b110100) == 6'b110100) cnt = cnt + 1;
            compute_count = cnt;
        end
    endfunction

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    result <= compute_count(num0, num1, num2, num3);
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule