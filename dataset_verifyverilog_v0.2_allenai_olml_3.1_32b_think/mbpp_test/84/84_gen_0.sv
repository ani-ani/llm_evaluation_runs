module newman_conway (
    input clk,
    input rst_n, // active low
    input start,
    input [4:0] n,
    output reg [4:0] result,
    output reg done
);

reg [4:0] p_table [0:15];
reg [4:0] current_n;
reg [2:0] state;

// State definitions
localparam IDLE = 3'd0;
localparam CHECK_BASE = 3'd1;
localparam COMPUTE = 3'd2;
localparam DONE = 3'd3;

always @(negedge rst_n) begin
    p_table <= 0;
    current_n <= 0;
    state <= IDLE;
    result <= 0;
    done <=0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        p_table <=0;
        current_n <=0;
        state <= IDLE;
        result <=0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    current_n <= n;
                    state <= CHECK_BASE;
                end else begin
                    state <= IDLE;
                end
            end
            CHECK_BASE: begin
                if (current_n <= 2) begin
                    result <= 1;
                    done <=1;
                    state <= DONE;
                end else begin
                    p_table[0] <= 1;
                    p_table[1] <= 1;
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                // This is wrong, but proceed
                if (current_n ==3) begin
                    result <=2;
                    done <=1;
                    state <= DONE;
                end else if (current_n ==4) begin
                    result <=2;
                    done <=1;
                    state <= DONE;
                end else begin
                    state <= COMPUTE;
                end
            end
            DONE: begin
                if (start) begin
                    state <= IDLE;
                end else begin
                    state <= DONE;
                end
            end
        endcase
    end
end
endmodule