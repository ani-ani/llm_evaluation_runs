module tree_checker (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input edge_valid,
    input [3:0] edge_u,
    input [3:0] edge_v,
    output reg result,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'b00;
localparam [1:0] LOAD = 2'b01;
localparam [1:0] CHECK = 2'b10;

reg [1:0] state;
reg [3:0] deg [0:15];
reg [3:0] edge_count;
reg has_deg2;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        edge_count <= 4'd0;
        has_deg2 <= 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            deg[i] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    for (i = 0; i < 16; i = i + 1) begin
                        deg[i] <= 4'd0;
                    end
                    edge_count <= 4'd0;
                    has_deg2 <= 1'b0;
                    state <= LOAD;
                end
            end

            LOAD: begin
                if (edge_valid) begin
                    if (edge_u >= 4'd1 && edge_u <= n && edge_v >= 4'd1 && edge_v <= n) begin
                        deg[edge_u - 1] <= deg[edge_u - 1] + 1;
                        deg[edge_v - 1] <= deg[edge_v - 1] + 1;
                    end
                    edge_count <= edge_count + 1;

                    if (edge_count + 1 == n - 1) begin
                        state <= CHECK;
                    end
                end
            end

            CHECK: begin
                has_deg2 <= 1'b0;
                if (deg[0] == 4'd2) has_deg2 <= 1'b1;
                if (deg[1] == 4'd2) has_deg2 <= 1'b1;
                if (deg[2] == 4'd2) has_deg2 <= 1'b1;
                if (deg[3] == 4'd2) has_deg2 <= 1'b1;
                if (deg[4] == 4'd2) has_deg2 <= 1'b1;
                if (deg[5] == 4'd2) has_deg2 <= 1'b1;
                if (deg[6] == 4'd2) has_deg2 <= 1'b1;
                if (deg[7] == 4'd2) has_deg2 <= 1'b1;
                if (deg[8] == 4'd2) has_deg2 <= 1'b1;
                if (deg[9] == 4'd2) has_deg2 <= 1'b1;
                if (deg[10] == 4'd2) has_deg2 <= 1'b1;
                if (deg[11] == 4'd2) has_deg2 <= 1'b1;
                if (deg[12] == 4'd2) has_deg2 <= 1'b1;
                if (deg[13] == 4'd2) has_deg2 <= 1'b1;
                if (deg[14] == 4'd2) has_deg2 <= 1'b1;
                if (deg[15] == 4'd2) has_deg2 <= 1'b1;
                
                result <= ~has_deg2;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule