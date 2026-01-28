module chaos_calculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] p0,
    input [7:0] p1,
    input [7:0] p2,
    input [7:0] p3,
    input [7:0] p4,
    input [7:0] p5,
    input [7:0] p6,
    input [7:0] p7,
    input [3:0] d0,
    input [3:0] d1,
    input [3:0] d2,
    input [3:0] d3,
    input [3:0] d4,
    input [3:0] d5,
    input [3:0] d6,
    input [3:0] d7,
    output reg [15:0] max_chaos,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_ST = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] active_coaches;
    reg [15:0] current_max_chaos;
    reg [3:0] step_counter;
    reg [3:0] destruction_order [0:7];
    reg [3:0] i;
    wire [7:0] next_active_coaches;
    reg [15:0] computed_total_chaos;

    assign next_active_coaches = active_coaches | (8'd1 << destruction_order[step_counter]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            active_coaches <= 8'd0;
            current_max_chaos <= 16'd0;
            step_counter <= 4'd0;
            done <= 1'b0;
            max_chaos <= 16'd0;
            destruction_order[0] <= 4'd0;
            destruction_order[1] <= 4'd0;
            destruction_order[2] <= 4'd0;
            destruction_order[3] <= 4'd0;
            destruction_order[4] <= 4'd0;
            destruction_order[5] <= 4'd0;
            destruction_order[6] <= 4'd0;
            destruction_order[7] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        destruction_order[0] <= d0 - 4'd1;
                        destruction_order[1] <= d1 - 4'd1;
                        destruction_order[2] <= d2 - 4'd1;
                        destruction_order[3] <= d3 - 4'd1;
                        destruction_order[4] <= d4 - 4'd1;
                        destruction_order[5] <= d5 - 4'd1;
                        destruction_order[6] <= d6 - 4'd1;
                        destruction_order[7] <= d7 - 4'd1;
                        step_counter <= n - 4'd1;
                        active_coaches <= 8'd0;
                        current_max_chaos <= 16'd0;
                        max_chaos <= 16'd0;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    active_coaches <= next_active_coaches;
                    if (computed_total_chaos > current_max_chaos) begin
                        current_max_chaos <= computed_total_chaos;
                    end
                    max_chaos <= current_max_chaos;
                    
                    if (step_counter == 4'd0) begin
                        state <= DONE_ST;
                    end else begin
                        step_counter <= step_counter - 4'd1;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        reg [15:0] total_chaos;
        reg [2:0] num_segments;
        reg [15:0] current_segment_sum;
        reg in_segment;
        integer i;
        
        total_chaos = 16'd0;
        num_segments = 3'd0;
        current_segment_sum = 16'd0;
        in_segment = 1'b0;
        
        for (i = 0; i < 8; i = i + 1) begin
            if (next_active_coaches[i]) begin
                if (!in_segment) begin
                    in_segment = 1'b1;
                    num_segments = num_segments + 3'd1;
                    current_segment_sum = {8'd0, 
                        (i == 0) ? p0 :
                        (i == 1) ? p1 :
                        (i == 2) ? p2 :
                        (i == 3) ? p3 :
                        (i == 4) ? p4 :
                        (i == 5) ? p5 :
                        (i == 6) ? p6 : p7};
                end else begin
                    current_segment_sum = current_segment_sum + {8'd0, 
                        (i == 0) ? p0 :
                        (i == 1) ? p1 :
                        (i == 2) ? p2 :
                        (i == 3) ? p3 :
                        (i == 4) ? p4 :
                        (i == 5) ? p5 :
                        (i == 6) ? p6 : p7};
                end
            end else begin
                if (in_segment) begin
                    total_chaos = total_chaos + (((current_segment_sum + 16'd9) / 16'd10) * 16'd10);
                    in_segment = 1'b0;
                    current_segment_sum = 16'd0;
                end
            end
        end
        
        if (in_segment) begin
            total_chaos = total_chaos + (((current_segment_sum + 16'd9) / 16'd10) * 16'd10);
        end
        
        computed_total_chaos = total_chaos * num_segments;
    end

endmodule