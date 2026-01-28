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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_RADII = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [7:0] radii_0;
    reg [7:0] radii_1;
    reg [7:0] radii_2;
    reg [7:0] radii_3;
    reg [7:0] max_diam;
    reg [7:0] temp_result;
    reg [2:0] state;
    reg [2:0] i;
    reg [1:0] compute_stage;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'd0;
            done <= 1'b0;
            state <= IDLE;
            max_diam <= 8'd0;
            temp_result <= 8'd0;
            radii_0 <= 8'd0;
            radii_1 <= 8'd0;
            radii_2 <= 8'd0;
            radii_3 <= 8'd0;
            i <= 3'd0;
            compute_stage <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_RADII;
                        i <= 3'd0;
                        compute_stage <= 2'd0;
                    end
                end

                COMPUTE_RADII: begin
                    // Compute radius = (diameter + 1) >> 1 for each tree
                    if (compute_stage == 2'd0) begin
                        radii_0 <= (diam1 + 8'd1) >> 1;
                        compute_stage <= 2'd1;
                    end else if (compute_stage == 2'd1) begin
                        if (num_trees >= 2) begin
                            radii_1 <= (diam2 + 8'd1) >> 1;
                        end
                        compute_stage <= 2'd2;
                    end else if (compute_stage == 2'd2) begin
                        if (num_trees >= 3) begin
                            radii_2 <= (diam3 + 8'd1) >> 1;
                        end
                        compute_stage <= 2'd3;
                    end else if (compute_stage == 2'd3) begin
                        if (num_trees >= 4) begin
                            radii_3 <= (diam4 + 8'd1) >> 1;
                        end
                        state <= FIND_MAX;
                        i <= 3'd0;
                        max_diam <= diam1;
                    end
                end

                FIND_MAX: begin
                    // Find maximum existing diameter
                    case (i)
                        3'd0: begin
                            if (num_trees > 1 && diam2 > max_diam) max_diam <= diam2;
                            i <= 3'd1;
                        end
                        3'd1: begin
                            if (num_trees > 2 && diam3 > max_diam) max_diam <= diam3;
                            i <= 3'd2;
                        end
                        3'd2: begin
                            if (num_trees > 3 && diam4 > max_diam) max_diam <= diam4;
                            state <= CALCULATE;
                            temp_result <= max_diam;
                            compute_stage <= 2'd0;
                        end
                        default: begin
                            state <= CALCULATE;
                            temp_result <= max_diam;
                            compute_stage <= 2'd0;
                        end
                    endcase
                end

                CALCULATE: begin
                    // Compute candidate diameters and take maximum
                    if (compute_stage == 2'd0) begin
                        if (num_trees >= 2) begin
                            if ((radii_0 + radii_1 + 8'd1) > temp_result) begin
                                temp_result <= radii_0 + radii_1 + 8'd1;
                            end
                        end
                        compute_stage <= 2'd1;
                    end else if (compute_stage == 2'd1) begin
                        if (num_trees >= 3) begin
                            if ((radii_0 + radii_1 + radii_2 + 8'd2) > temp_result) begin
                                temp_result <= radii_0 + radii_1 + radii_2 + 8'd2;
                            end
                        end
                        compute_stage <= 2'd2;
                    end else if (compute_stage == 2'd2) begin
                        if (num_trees >= 4) begin
                            if ((radii_0 + radii_1 + radii_2 + radii_3 + 8'd2) > temp_result) begin
                                temp_result <= radii_0 + radii_1 + radii_2 + radii_3 + 8'd2;
                            end
                        end
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule