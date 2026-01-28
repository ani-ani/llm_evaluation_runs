module fence_painter #(
    parameter N = 8,
    parameter S = 16,
    parameter C = 8
) (
    input clk,
    input rst_n,
    input start,
    input load_en,
    input [2:0] offer_color,
    input [3:0] offer_start,
    input [3:0] offer_end,
    input [2:0] offer_index,
    output reg [3:0] min_count,
    output reg valid,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] INIT            = 3'd1;
    localparam [2:0] LOOP_START      = 3'd2;
    localparam [2:0] CHECK_OFFER     = 3'd3;
    localparam [2:0] EVALUATE        = 3'd4;
    localparam [2:0] INCREMENT_SUBSET= 3'd5;
    localparam [2:0] DONE_STATE      = 3'd6;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] color_reg [0:N-1];
    reg [3:0] start_reg [0:N-1];
    reg [3:0] end_reg [0:N-1];
    reg [S-1:0] offer_mask [0:N-1];
    reg [5:0] subset_counter;
    reg [2:0] offer_idx;
    reg [S-1:0] coverage_mask;
    reg [C-1:0] color_mask;
    reg [3:0] subset_size;
    reg [3:0] best_count;
    reg found;
    
    integer i; // Loop variable
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            min_count <= 4'd0;
            subset_counter <= 6'd0;
            offer_idx <= 3'd0;
            coverage_mask <= {S{1'b0}};
            color_mask <= {C{1'b0}};
            subset_size <= 4'd0;
            best_count <= 4'd15;
            found <= 1'b0;
            
            // Initialize array registers
            for (i = 0; i < N; i = i + 1) begin
                color_reg[i] <= 3'd0;
                start_reg[i] <= 4'd0;
                end_reg[i] <= 4'd0;
                offer_mask[i] <= {S{1'b0}};
            end
        end
        else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end
                    else if (load_en) begin
                        color_reg[offer_index] <= offer_color;
                        start_reg[offer_index] <= offer_start;
                        end_reg[offer_index] <= offer_end;
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    subset_counter <= 6'd0;
                    best_count <= 4'd15;
                    found <= 1'b0;
                    next_state <= LOOP_START;
                end
                
                LOOP_START: begin
                    if (subset_counter == (1 << N)) begin
                        next_state <= DONE_STATE;
                    end
                    else begin
                        coverage_mask <= {S{1'b0}};
                        color_mask <= {C{1'b0}};
                        subset_size <= 4'd0;
                        offer_idx <= 3'd0;
                        next_state <= CHECK_OFFER;
                    end
                end
                
                CHECK_OFFER: begin
                    if (offer_idx == 3'(N)) begin
                        next_state <= EVALUATE;
                    end
                    else begin
                        if (subset_counter[offer_idx]) begin
                            subset_size <= subset_size + 4'd1;
                            coverage_mask <= coverage_mask | offer_mask[offer_idx];
                            color_mask <= color_mask | ({{(C-1){1'b0}},1'b1} << color_reg[offer_idx]);
                        end
                        offer_idx <= offer_idx + 3'd1;
                        next_state <= CHECK_OFFER;
                    end
                end
                
                EVALUATE: begin
                    if (coverage_mask == {S{1'b1}}) begin
                        reg [2:0] color_count;
                        color_count = 3'd0;
                        for (i = 0; i < C; i = i + 1) begin
                            color_count = color_count + color_mask[i];
                        end
                        if (color_count <= 3'd3) begin
                            if (subset_size < best_count) begin
                                best_count <= subset_size;
                                found <= 1'b1;
                            end
                        end
                    end
                    subset_counter <= subset_counter + 6'd1;
                    next_state <= LOOP_START;
                end
                
                DONE_STATE: begin
                    min_count <= best_count;
                    valid <= found;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Combinational offer mask generation
    generate
        genvar j;
        for (j = 0; j < N; j = j + 1) begin : mask_gen
            always @(*) begin
                if (start_reg[j] <= end_reg[j]) begin
                    offer_mask[j] = (({S{1'b1}} >> (S - (end_reg[j] - start_reg[j] + 1)))) << start_reg[j];
                end
                else begin
                    offer_mask[j] = {S{1'b0}};
                end
            end
        end
    endgenerate
endmodule