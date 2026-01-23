module kth_sequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [13:0] k,
    output reg [2:0] seq_0,
    output reg [2:0] seq_1,
    output reg [2:0] seq_2,
    output reg [2:0] seq_3,
    output reg [2:0] seq_4,
    output reg [2:0] seq_5,
    output reg [2:0] seq_6,
    output reg [2:0] seq_7,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FIND_A  = 3'd1;
    localparam [2:0] UPDATE  = 3'd2;
    localparam [2:0] NEXT    = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    // Registers
    reg [2:0] state;
    reg [3:0] s;           // current prefix sum modulo n
    reg [7:0] used;        // bitmask for used residues
    reg [3:0] i;           // current position (1 to n-1)
    reg [13:0] rem_k;      // remaining k during search
    reg [3:0] a;           // current candidate a
    reg [13:0] count_per;  // factorial(n - i - 1)

    // Combinational signals
    wire [3:0] new_s_temp = s + a;
    wire [3:0] new_s = (new_s_temp >= n) ? new_s_temp - n : new_s_temp;
    wire valid = (used[new_s] == 1'b0);

    // Compute factorial lookup
    always @(*) begin
        case (n - i - 1)
            4'd0: count_per = 14'd1;
            4'd1: count_per = 14'd1;
            4'd2: count_per = 14'd2;
            4'd3: count_per = 14'd6;
            4'd4: count_per = 14'd24;
            4'd5: count_per = 14'd120;
            4'd6: count_per = 14'd720;
            default: count_per = 14'd0;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            seq_0 <= 3'd0;
            seq_1 <= 3'd0;
            seq_2 <= 3'd0;
            seq_3 <= 3'd0;
            seq_4 <= 3'd0;
            seq_5 <= 3'd0;
            seq_6 <= 3'd0;
            seq_7 <= 3'd0;
            s <= 4'd0;
            used <= 8'd0;
            i <= 4'd0;
            rem_k <= 14'd0;
            a <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        s <= 4'd0;
                        used <= 8'b00000001;
                        i <= 4'd1;
                        rem_k <= k;
                        a <= 4'd1;
                        state <= FIND_A;
                    end
                end

                FIND_A: begin
                    if (valid) begin
                        if (rem_k > count_per) begin
                            rem_k <= rem_k - count_per;
                            a <= a + 4'd1;
                        end else begin
                            state <= UPDATE;
                        end
                    end else begin
                        a <= a + 4'd1;
                    end
                end

                UPDATE: begin
                    case (i)
                        4'd1: seq_0 <= a[2:0];
                        4'd2: seq_1 <= a[2:0];
                        4'd3: seq_2 <= a[2:0];
                        4'd4: seq_3 <= a[2:0];
                        4'd5: seq_4 <= a[2:0];
                        4'd6: seq_5 <= a[2:0];
                        4'd7: seq_6 <= a[2:0];
                        4'd8: seq_7 <= a[2:0];
                        default: begin
                            seq_0 <= seq_0;
                            seq_1 <= seq_1;
                            seq_2 <= seq_2;
                            seq_3 <= seq_3;
                            seq_4 <= seq_4;
                            seq_5 <= seq_5;
                            seq_6 <= seq_6;
                            seq_7 <= seq_7;
                        end
                    endcase
                    s <= new_s;
                    used <= used | (8'b00000001 << new_s);
                    state <= NEXT;
                end

                NEXT: begin
                    i <= i + 4'd1;
                    if (i + 4'd1 > n - 4'd1) begin
                        state <= DONE;
                    end else begin
                        state <= FIND_A;
                        a <= 4'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule