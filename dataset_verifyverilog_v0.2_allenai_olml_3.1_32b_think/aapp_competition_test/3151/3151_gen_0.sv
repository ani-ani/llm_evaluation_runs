module swimming_hall (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] m,
    output reg [7:0] k,
    output reg valid,
    output reg impossible,
    output reg done
);

reg [7:0] n_val;
reg [7:0] i_count;
reg [2:0] state;
reg [7:0] temp_m, temp_k;

localparam IDLE = 3'd0,
           CHECK = 3'd1,
           FOUND = 3'd2,
           IMPOSSIBLE = 3'd3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        n_val <= 8'b0;
        i_count <= 8'd0;
        state <= IDLE;
        m <= 8'd0;
        k <= 8'd0;
        valid <= 1'b0;
        impossible <= 1'b0;
        done <= 1'b0;
        temp_m <= 8'd0;
        temp_k <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    n_val <= n;
                    i_count <= 8'd1;
                    state <= CHECK;
                    m <= 8'd0;
                    k <= 8'd0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                end
            end
            CHECK: begin
                if (i_count > n_val) begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    state <= IMPOSSIBLE;
                end else begin
                    if (n_val % i_count == 0) begin
                        if (i_count * i_count <= n_val && ((i_count + (n_val / i_count)) % 2) == 0) begin
                            temp_m = (i_count + (n_val / i_count)) / 2;
                            temp_k = ((n_val / i_count) - i_count) / 2;
                            m <= temp_m;
                            k <= temp_k;
                            valid <= 1'b1;
                            done <= 1'b1;
                            state <= FOUND;
                        end
                    end
                    if (state == CHECK) begin
                        i_count <= i_count + 1;
                    end
                end
            end
            FOUND: begin
                // Do nothing
            end
            IMPOSSIBLE: begin
                // Do nothing
            end
        endcase
    end
end
// End module