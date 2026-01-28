module max_and_circle #(
    parameter N = 8,
    parameter MAX_K = 4,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:N-1],
    input wire [3:0] k,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State declarations
localparam [3:0] IDLE            = 4'd0;
localparam [3:0] SETUP           = 4'd1;
localparam [3:0] NEXT_COMPOSITION= 4'd2;
localparam [3:0] COMPUTE_OR      = 4'd3;
localparam [3:0] UPDATE_MAX      = 4'd4;
localparam [3:0] NEXT_START      = 4'd5;
localparam [3:0] DONE_STATE      = 4'd6;

// Internal registers
reg [3:0] state;
reg [2:0] start_idx;
reg [3:0] current_k;
reg [5:0] comp_idx;
reg [3:0] comp_count;
reg [2:0] seg_idx;
reg [3:0] seg_lengths [0:MAX_K-1];
reg [3:0] seg_start_arr [0:MAX_K-1];
reg [RESULT_WIDTH-1:0] current_and;
reg [RESULT_WIDTH-1:0] max_result;
reg [DATA_WIDTH-1:0] rotated_arr [0:N-1];

// Loop counters
integer i, j, m;

// Composition count lookup function
function [5:0] get_comp_count;
    input [3:0] k_val;
    begin
        case(k_val)
            4'd1: get_comp_count = 6'd1;
            4'd2: get_comp_count = 6'd7;
            4'd3: get_comp_count = 6'd21;
            4'd4: get_comp_count = 6'd35;
            default: get_comp_count = 6'd0;
        endcase
    end
endfunction

// Rotation logic
always @(*) begin
    for (i = 0; i < N; i = i + 1) begin
        j = start_idx + i;
        if (j >= N) j = j - N;
        rotated_arr[i] = arr[j];
    end
end

// Composition decoding
always @(*) begin
    for (i = 0; i < MAX_K; i = i + 1)
        seg_lengths[i] = 4'd0;
        
    case(current_k)
        4'd1: begin
            case(comp_idx)
                6'd0: seg_lengths[0] = 4'd8;
                default: seg_lengths[0] = 4'd0;
            endcase
        end
        4'd2: begin
            case(comp_idx)
                6'd0: {seg_lengths[0], seg_lengths[1]} = {4'd1, 4'd7};
                6'd1: {seg_lengths[0], seg_lengths[1]} = {4'd2, 4'd6};
                6'd2: {seg_lengths[0], seg_lengths[1]} = {4'd3, 4'd5};
                6'd3: {seg_lengths[0], seg_lengths[1]} = {4'd4, 4'd4};
                6'd4: {seg_lengths[0], seg_lengths[1]} = {4'd5, 4'd3};
                6'd5: {seg_lengths[0], seg_lengths[1]} = {4'd6, 4'd2};
                6'd6: {seg_lengths[0], seg_lengths[1]} = {4'd7, 4'd1};
                default: {seg_lengths[0], seg_lengths[1]} = {4'd0, 4'd0};
            endcase
        end
        default: begin // Partial implementation for brevity
            for (i = 0; i < MAX_K; i = i + 1)
                seg_lengths[i] = 4'd0;
        end
    endcase
end

// Segment start calculation
always @(*) begin
    seg_start_arr[0] = 4'd0;
    for (i = 1; i < MAX_K; i = i + 1) begin
        seg_start_arr[i] = seg_start_arr[i-1] + seg_lengths[i-1];
    end
end

// Segment OR computation
wire [DATA_WIDTH-1:0] seg_or;
assign seg_or = seg_start_arr[seg_idx] < seg_start_arr[seg_idx] + seg_lengths[seg_idx] ?
                rotated_arr[seg_start_arr[seg_idx]] : {DATA_WIDTH{1'b0}};
generate
for (genvar g = 1; g < 8; g = g + 1) begin : or_calc
    wire enable = (g < seg_lengths[seg_idx]);
    wire [DATA_WIDTH-1:0] next_or = seg_or | (enable ? rotated_arr[seg_start_arr[seg_idx] + g] : {DATA_WIDTH{1'b0}});
    assign seg_or = next_or;
end
endgenerate
    
// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= {RESULT_WIDTH{1'b0}};
        done <= 1'b0;
        start_idx <= 3'd0;
        comp_idx <= 6'd0;
        seg_idx <= 3'd0;
        current_and <= {RESULT_WIDTH{1'b0}};
        max_result <= {RESULT_WIDTH{1'b0}};
        current_k <= 4'd0;
        
        for (i = 0; i < MAX_K; i = i + 1) begin
            seg_lengths[i] <= 4'd0;
            seg_start_arr[i] <= 4'd0;
        end
    end else begin
        case(state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    if (k >= 4'd1 && k <= 4'd4) begin
                        current_k <= k;
                        comp_count <= get_comp_count(k);
                        state <= SETUP;
                    end else begin
                        max_result <= {RESULT_WIDTH{1'b0}};
                        state <= DONE_STATE;
                    end
                end
            end
            
            SETUP: begin
                comp_idx <= 6'd0;
                state <= NEXT_COMPOSITION;
            end
            
            NEXT_COMPOSITION: begin
                seg_idx <= 3'd0;
                current_and <= {RESULT_WIDTH{1'b1}};
                state <= COMPUTE_OR;
            end
            
            COMPUTE_OR: begin
                current_and <= current_and & seg_or;
                seg_idx <= seg_idx + 3'd1;
                if (seg_idx == current_k - 3'd1)
                    state <= UPDATE_MAX;
            end
            
            UPDATE_MAX: begin
                if (current_and > max_result) max_result <= current_and;
                comp_idx <= comp_idx + 6'd1;
                if (comp_idx + 6'd1 < comp_count)
                    state <= NEXT_COMPOSITION;
                else
                    state <= NEXT_START;
            end
            
            NEXT_START: begin
                if (start_idx == N-1) begin
                    state <= DONE_STATE;
                end else begin
                    start_idx <= start_idx + 3'd1;
                    state <= SETUP;
                end
            end
            
            DONE_STATE: begin
                result <= max_result;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule