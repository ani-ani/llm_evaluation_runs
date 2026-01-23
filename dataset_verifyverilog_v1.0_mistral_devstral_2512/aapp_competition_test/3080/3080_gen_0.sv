module ski_resort (
    input clk,
    input rst_n,
    input start,
    input [63:0] reach,
    input [2:0] k_in,
    input [2:0] a_in,
    input [23:0] t_in,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    parameter N = 8;
    parameter MAX_MASK = 256;

    // Internal registers
    reg [63:0] reach_reg;
    reg [2:0] k_reg;
    reg [2:0] a_reg;
    reg [23:0] t_reg;
    reg [7:0] mask_counter;
    reg [15:0] result_reg;
    reg done_reg;
    reg [3:0] state;
    reg [2:0] target_idx;
    reg [3:0] node_idx;
    reg [7:0] anc_masks [0:7];
    reg [7:0] combined_anc;
    reg [7:0] current_mask;
    reg [3:0] popcnt;
    reg valid_flag;
    reg [2:0] inner_idx;

    // Function to compute popcount of 8-bit value
    function [3:0] popcount8;
        input [7:0] mask;
        integer i;
        begin
            popcount8 = 0;
            for (i = 0; i < 8; i = i + 1) begin
                popcount8 = popcount8 + mask[i];
            end
        end
    endfunction

    // State definitions
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_LOAD = 4'd1;
    localparam [3:0] S_COMP_ANC = 4'd2;
    localparam [3:0] S_INIT_ENUM = 4'd3;
    localparam [3:0] S_ENUM_LOOP = 4'd4;
    localparam [3:0] S_CHECK_TARGETS = 4'd5;
    localparam [3:0] S_VALID = 4'd6;
    localparam [3:0] S_NEXT = 4'd7;
    localparam [3:0] S_DONE = 4'd8;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done_reg <= 1'b0;
            result_reg <= 16'd0;
            mask_counter <= 8'd0;
            reach_reg <= 64'd0;
            k_reg <= 3'd0;
            a_reg <= 3'd0;
            t_reg <= 24'd0;
            current_mask <= 8'd0;
            target_idx <= 3'd0;
            node_idx <= 4'd0;
            inner_idx <= 3'd0;
            valid_flag <= 1'b0;
            combined_anc <= 8'd0;
            // Clear anc_masks
            for (integer i = 0; i < 8; i = i + 1) begin
                anc_masks[i] <= 8'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        state <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    reach_reg <= reach;
                    k_reg <= k_in;
                    a_reg <= a_in;
                    t_reg <= t_in;
                    state <= S_COMP_ANC;
                    target_idx <= 3'd0;
                    node_idx <= 4'd0;
                    combined_anc <= 8'd0;
                    for (integer i = 0; i < 8; i = i + 1) begin
                        anc_masks[i] <= 8'd0;
                    end
                end

                S_COMP_ANC: begin
                    if (target_idx < a_reg) begin
                        if (node_idx < 8) begin
                            if (reach_reg[node_idx*8 + t_reg[target_idx*3 +: 3]]) begin
                                anc_masks[target_idx][node_idx] <= 1'b1;
                            end else begin
                                anc_masks[target_idx][node_idx] <= 1'b0;
                            end
                            node_idx <= node_idx + 4'd1;
                        end else begin
                            combined_anc <= combined_anc | anc_masks[target_idx];
                            target_idx <= target_idx + 3'd1;
                            node_idx <= 4'd0;
                        end
                    end else begin
                        state <= S_INIT_ENUM;
                    end
                end

                S_INIT_ENUM: begin
                    mask_counter <= 8'd1;
                    result_reg <= 16'd0;
                    state <= S_ENUM_LOOP;
                end

                S_ENUM_LOOP: begin
                    if (mask_counter == 8'd0) begin
                        state <= S_DONE;
                    end else begin
                        popcnt <= popcount8(mask_counter);
                        if (popcnt == k_reg && (mask_counter & ~combined_anc) == 8'd0) begin
                            current_mask <= mask_counter;
                            target_idx <= 3'd0;
                            valid_flag <= 1'b1;
                            state <= S_CHECK_TARGETS;
                        end else begin
                            state <= S_NEXT;
                        end
                    end
                end

                S_CHECK_TARGETS: begin
                    if (target_idx >= a_reg) begin
                        state <= S_VALID;
                    end else begin
                        if (popcount8(current_mask & anc_masks[target_idx]) != 4'd1) begin
                            valid_flag <= 1'b0;
                            state <= S_NEXT;
                        end else begin
                            target_idx <= target_idx + 3'd1;
                        end
                    end
                end

                S_VALID: begin
                    result_reg <= result_reg + 16'd1;
                    state <= S_NEXT;
                end

                S_NEXT: begin
                    if (mask_counter == 8'd255) begin
                        state <= S_DONE;
                    end else begin
                        mask_counter <= mask_counter + 8'd1;
                        state <= S_ENUM_LOOP;
                    end
                end

                S_DONE: begin
                    result <= result_reg;
                    done_reg <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign done = done_reg;

endmodule