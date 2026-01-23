module kth_sequence (
    input clk,
    input rst_n,
    input start,
    input [31:0] k,
    output reg [3:0] result,
    output reg valid,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        COUNTING,
        CHECKING,
        OUTPUT
    } state_t;

    state_t state;
    reg [31:0] count = 0;
    reg [3:0] seq [0:3];
    reg [3:0] seq_reg [0:3];
    reg [3:0] idx = 0;
    reg [3:0] sub_idx = 0;
    reg [3:0] sum = 0;
    reg [3:0] i = 0;
    reg [3:0] j = 0;
    reg valid_seq = 0;
    reg [3:0] out_idx = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            idx <= 0;
            sub_idx <= 0;
            sum <= 0;
            i <= 0;
            j <= 0;
            valid_seq <= 0;
            out_idx <= 0;
            valid <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COUNTING;
                        count <= 0;
                        idx <= 0;
                        sub_idx <= 0;
                        sum <= 0;
                        i <= 0;
                        j <= 0;
                        valid_seq <= 0;
                        out_idx <= 0;
                        valid <= 0;
                        done <= 0;
                        result <= 0;
                    end
                end

                COUNTING: begin
                    if (idx == 4) begin
                        state <= CHECKING;
                        i <= 0;
                        j <= 0;
                        sum <= 0;
                        valid_seq <= 1;
                    end else begin
                        if (sub_idx == 0) begin
                            seq[idx] <= 1;
                        end else if (seq[idx] == 4) begin
                            seq[idx] <= 1;
                            idx <= idx + 1;
                            sub_idx <= 0;
                        end else begin
                            seq[idx] <= seq[idx] + 1;
                        end
                        sub_idx <= sub_idx + 1;
                    end
                end

                CHECKING: begin
                    if (valid_seq) begin
                        if (i == 4) begin
                            if (count + 1 == k) begin
                                for (int m = 0; m < 4; m = m + 1) begin
                                    seq_reg[m] <= seq[m];
                                end
                                state <= OUTPUT;
                                out_idx <= 0;
                                valid <= 1;
                            end
                            count <= count + 1;
                            state <= COUNTING;
                            idx <= 0;
                            sub_idx <= 0;
                        end else begin
                            if (j == 4) begin
                                i <= i + 1;
                                j <= i;
                                sum <= seq[i];
                            end else begin
                                sum <= sum + seq[j];
                                if (sum % 5 == 0) begin
                                    valid_seq <= 0;
                                end
                                j <= j + 1;
                            end
                        end
                    end else begin
                        state <= COUNTING;
                        idx <= 0;
                        sub_idx <= 0;
                    end
                end

                OUTPUT: begin
                    if (out_idx == 4) begin
                        done <= 1;
                        valid <= 0;
                        state <= IDLE;
                    end else begin
                        result <= seq_reg[out_idx];
                        out_idx <= out_idx + 1;
                    end
                end
            endcase
        end
    end

endmodule