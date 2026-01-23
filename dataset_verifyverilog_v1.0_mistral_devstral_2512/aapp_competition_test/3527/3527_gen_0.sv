module network_optimizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] diam1,
    input [7:0] diam2,
    input [7:0] diam3,
    input [7:0] diam4,
    input [2:0] num_trees,
    output reg [7:0] result,
    output reg done
);

    reg [7:0] radii [0:3];
    reg [7:0] max_diam;
    reg [7:0] temp_result;
    reg [2:0] state;
    reg [2:0] i;
    reg [2:0] j;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_RADII = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE = 3'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
            state <= IDLE;
            max_diam <= 8'd0;
            temp_result <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            radii[0] <= 8'd0;
            radii[1] <= 8'd0;
            radii[2] <= 8'd0;
            radii[3] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && num_trees >= 1 && num_trees <= 4) begin
                        state <= COMPUTE_RADII;
                        i <= 3'd0;
                    end
                end
                
                COMPUTE_RADII: begin
                    case (i)
                        3'd0: radii[0] <= (diam1 + 1) >> 1;
                        3'd1: radii[1] <= (diam2 + 1) >> 1;
                        3'd2: radii[2] <= (diam3 + 1) >> 1;
                        3'd3: radii[3] <= (diam4 + 1) >> 1;
                    endcase
                    
                    if (i < num_trees - 1) begin
                        i <= i + 1;
                    end else begin
                        state <= FIND_MAX;
                        i <= 3'd0;
                    end
                end
                
                FIND_MAX: begin
                    if (i == 0) begin
                        max_diam <= diam1;
                        i <= 1;
                    end else if (i < num_trees) begin
                        case (i)
                            1: if (diam2 > max_diam) max_diam <= diam2;
                            2: if (diam3 > max_diam) max_diam <= diam3;
                            3: if (diam4 > max_diam) max_diam <= diam4;
                        endcase
                        i <= i + 1;
                    end else begin
                        state <= CALCULATE;
                        temp_result <= max_diam;
                        i <= 3'd0;
                        j <= 3'd0;
                    end
                end
                
                CALCULATE: begin
                    if (num_trees >= 2) begin
                        temp_result <= (radii[0] + radii[1] + 1 > temp_result) ?
                                       radii[0] + radii[1] + 1 : temp_result;
                    end
                    if (num_trees >= 3) begin
                        temp_result <= (radii[0] + radii[1] + radii[2] + 2 > temp_result) ?
                                       radii[0] + radii[1] + radii[2] + 2 : temp_result;
                    end
                    if (num_trees >= 4) begin
                        temp_result <= (radii[0] + radii[1] + radii[2] + radii[3] + 2 > temp_result) ?
                                       radii[0] + radii[1] + radii[2] + radii[3] + 2 : temp_result;
                    end
                    
                    state <= DONE;
                end
                
                DONE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule