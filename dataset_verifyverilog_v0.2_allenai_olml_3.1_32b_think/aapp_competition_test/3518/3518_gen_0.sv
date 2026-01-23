module min_co2_match (
    input clk,
    input rst_n,
    input start,
    input [2:0] p_idx,
    input [31:0] weight,
    input weight_valid,
    output reg [31:0] result,
    output reg done,
    output reg impossible
);

localparam IDLE = 3'd0, LOAD = 3'd1, COMPUTE = 3'd2, DONE_STATE = 3'd3;
reg [2:0] state;
reg [31:0] adj [7:0][7:0];
reg [4:0] count;
reg [31:0] temp_result;
reg valid;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        impossible <= 0;
        result <= 0;
        count <= 0;
        temp_result <= 0;
        valid <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD;
                else state <= IDLE;
            end
            LOAD: begin
                if (!start) begin
                    state <= COMPUTE;
                end else begin
                    if (weight_valid) begin
                        adj[p_idx][q_idx] = weight;
                        adj[q_idx][p_idx] = weight;
                    end
                end
            end
            COMPUTE: begin
                if (count < 20) begin
                    count <= count + 1;
                    if (count == 1) begin
                        valid = 1'b1;
                        if (adj[0][1] == 0) valid = 1'b0;
                        if (adj[2][3] == 0) valid = 1'b0;
                        if (adj[4][5] == 0) valid = 1'b0;
                        if (adj[6][7] == 0) valid = 1'b0;
                        if (valid) begin
                            temp_result = adj[0][1] + adj[2][3] + adj[4][5] + adj[6][7];
                            result = temp_result;
                            impossible = 1'b0;
                        end else begin
                            result = 32'd0;
                            impossible = 1'b1;
                        end
                    end
                end else begin
                    state <= DONE_STATE;
                    done <= 1;
                end
                state <= COMPUTE;
            end
            DONE_STATE: state <= DONE_STATE;
        endcase
    end
end