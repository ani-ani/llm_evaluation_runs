module tv_recorder(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] k,
    input [15:0] start_times [0:7],
    input [15:0] end_times [0:7],
    output reg [3:0] count,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    reg [2:0] state;
    reg [3:0] show_idx;
    reg [3:0] machine_idx;
    reg [15:0] machine_end [0:3];
    
    reg [15:0] sorted_start [0:7];
    reg [15:0] sorted_end [0:7];
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            show_idx <= 4'd0;
            machine_idx <= 4'd0;
            for (i = 0; i < 4; i = i + 1) begin
                machine_end[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SORT;
                        for (i = 0; i < 8; i = i + 1) begin
                            sorted_start[i] <= start_times[i];
                            sorted_end[i] <= end_times[i];
                        end
                    end
                end
                
                SORT: begin
                    for (i = 0; i < 7; i = i + 1) begin
                        if (sorted_end[i] > sorted_end[i+1]) begin
                            sorted_end[i] <= sorted_end[i+1];
                            sorted_end[i+1] <= sorted_end[i];
                            sorted_start[i] <= sorted_start[i+1];
                            sorted_start[i+1] <= sorted_start[i];
                        end
                    end
                    for (i = 0; i < 6; i = i + 1) begin
                        if (sorted_end[i] > sorted_end[i+1]) begin
                            sorted_end[i] <= sorted_end[i+1];
                            sorted_end[i+1] <= sorted_end[i];
                            sorted_start[i] <= sorted_start[i+1];
                            sorted_start[i+1] <= sorted_start[i];
                        end
                    end
                    state <= INIT;
                end
                
                INIT: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        machine_end[i] <= 16'd0;
                    end
                    count <= 4'd0;
                    show_idx <= 4'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    if (show_idx < n && show_idx < 8) begin
                        reg found = 1'b0;
                        reg [15:0] max_end = 16'd0;
                        reg [2:0] best_machine = 3'd0;
                        
                        for (machine_idx = 0; machine_idx < k && machine_idx < 4; machine_idx = machine_idx + 1) begin
                            if (machine_end[machine_idx] <= sorted_start[show_idx]) begin
                                if (machine_end[machine_idx] > max_end || !found) begin
                                    max_end = machine_end[machine_idx];
                                    best_machine = machine_idx;
                                    found = 1'b1;
                                end
                            end
                        end
                        
                        if (found) begin
                            machine_end[best_machine] <= sorted_end[show_idx];
                            count <= count + 1'b1;
                        end else if (show_idx < k) begin
                            machine_end[show_idx] <= sorted_end[show_idx];
                            count <= count + 1'b1;
                        end
                        
                        show_idx <= show_idx + 1'b1;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule