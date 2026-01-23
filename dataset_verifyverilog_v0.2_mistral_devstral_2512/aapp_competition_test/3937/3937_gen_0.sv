module gcd_sequence_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] k_in,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [7:0] x_in,
    input [7:0] m_limit,
    output reg found,
    output reg [7:0] j_out,
    output reg valid
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t state;
    reg [7:0] j;
    reg [2:0] l;
    reg [7:0] a [0:7];

    // GCD LUT for values 0..255
    function automatic [7:0] gcd_lut;
        input [7:0] a, b;
        reg [7:0] temp_a, temp_b;
        begin
            temp_a = a;
            temp_b = b;
            while (temp_b != 0) begin
                if (temp_a > temp_b) begin
                    temp_a = temp_a - temp_b;
                end else begin
                    temp_b = temp_b - temp_a;
                end
            end
            gcd_lut = temp_a;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 0;
            j_out <= 0;
            valid <= 0;
            j <= 0;
            l <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        found <= 0;
                        j <= 0;
                        l <= 0;
                        valid <= 0;
                        // Load sequence
                        a[0] <= a_0;
                        a[1] <= a_1;
                        a[2] <= a_2;
                        a[3] <= a_3;
                        a[4] <= a_4;
                        a[5] <= a_5;
                        a[6] <= a_6;
                        a[7] <= a_7;
                    end
                end
                PROCESSING: begin
                    if (l == 0) begin
                        // Check if j + k_in - 1 > m_limit
                        if (j + k_in - 1 > m_limit) begin
                            state <= DONE;
                            found <= 0;
                            valid <= 1;
                        end else begin
                            // Check GCD(x_in, j + l) == a[l]
                            if (gcd_lut(x_in, j + l) == a[l]) begin
                                l <= l + 1;
                            end else begin
                                j <= j + 1;
                            end
                        end
                    end else begin
                        // Check next element in sequence
                        if (gcd_lut(x_in, j + l) == a[l]) begin
                            if (l == k_in - 1) begin
                                // Sequence found
                                state <= DONE;
                                found <= 1;
                                j_out <= j;
                                valid <= 1;
                            end else begin
                                l <= l + 1;
                            end
                        end else begin
                            j <= j + 1;
                            l <= 0;
                        end
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        valid <= 0;
                    end
                end
            endcase
        end
    end

endmodule