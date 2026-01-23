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
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT = 3'b001;
    localparam [2:0] LOOP_START = 3'b010;
    localparam [2:0] CHECK_OFFER = 3'b011;
    localparam [2:0] EVALUATE = 3'b100;
    localparam [2:0] INCREMENT_SUBSET = 3'b101;
    localparam [2:0] DONE = 3'b110;
    
    // Internal registers
    reg [2:0] state;
    reg [5:0] subset_counter;
    reg [2:0] offer_idx;
    reg [S-1:0] coverage_mask;
    reg [C-1:0] color_mask;
    reg [3:0] subset_size;
    reg [3:0] best_count;
    reg found;
    
    // Offer storage registers
    reg [2:0] color_reg [0:N-1];
    reg [3:0] start_reg [0:N-1];
    reg [3:0] end_reg [0:N-1];
    
    // Offer mask computation
    reg [S-1:0] offer_mask [0:N-1];
    integer i;
    
    always @(*) begin
        for (i = 0; i < N; i = i + 1) begin
            if (start_reg[i] <= end_reg[i]) begin
                offer_mask[i] = ((1 << (end_reg[i] - start_reg[i] + 1)) - 1) << start_reg[i];
            end else begin
                offer_mask[i] = {S{1'b0}};
            end
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_count <= 4'b0;
            valid <= 1'b0;
            done <= 1'b0;
            subset_counter <= 6'b0;
            offer_idx <= 3'b0;
            coverage_mask <= {S{1'b0}};
            color_mask <= {C{1'b0}};
            subset_size <= 4'b0;
            best_count <= 4'b15;
            found <= 1'b0;
            
            for (i = 0; i < N; i = i + 1) begin
                color_reg[i] <= 3'b0;
                start_reg[i] <= 4'b0;
                end_reg[i] <= 4'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end else if (load_en) begin
                        color_reg[offer_index] <= offer_color;
                        start_reg[offer_index] <= offer_start;
                        end_reg[offer_index] <= offer_end;
                    end
                end
                
                INIT: begin
                    subset_counter <= 6'b0;
                    best_count <= 4'b15;
                    found <= 1'b0;
                    state <= LOOP_START;
                end
                
                LOOP_START: begin
                    if (subset_counter == (1 << N)) begin
                        state <= DONE;
                    end else begin
                        coverage_mask <= {S{1'b0}};
                        color_mask <= {C{1'b0}};
                        subset_size <= 4'b0;
                        offer_idx <= 3'b0;
                        state <= CHECK_OFFER;
                    end
                end
                
                CHECK_OFFER: begin
                    if (offer_idx == N) begin
                        state <= EVALUATE;
                    end else begin
                        if (subset_counter[offer_idx]) begin
                            subset_size <= subset_size + 1;
                            coverage_mask <= coverage_mask | offer_mask[offer_idx];
                            color_mask <= color_mask | (1 << color_reg[offer_idx]);
                        end
                        offer_idx <= offer_idx + 1;
                    end
                end
                
                EVALUATE: begin
                    if (coverage_mask == {S{1'b1}}) begin
                        integer popcount;
                        popcount = 0;
                        for (i = 0; i < C; i = i + 1) begin
                            popcount = popcount + color_mask[i];
                        end
                        if (popcount <= 3) begin
                            if (subset_size < best_count) begin
                                best_count <= subset_size;
                                found <= 1'b1;
                            end
                        end
                    end
                    state <= INCREMENT_SUBSET;
                end
                
                INCREMENT_SUBSET: begin
                    subset_counter <= subset_counter + 1;
                    state <= LOOP_START;
                end
                
                DONE: begin
                    if (found) begin
                        min_count <= best_count;
                        valid <= 1'b1;
                    end else begin
                        min_count <= 4'b0;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule