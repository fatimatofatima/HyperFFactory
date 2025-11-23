class AwarenessSystem:
    def get_capabilities(self):
        return {
            'memory': '8 قواعد بيانات',
            'services': '5 خدمات نشطة', 
            'scripts': '415 سكربت',
            'status': 'نشط وجاهز'
        }
    
    def report_status(self):
        caps = self.get_capabilities()
        print('👁️ النظام الواعي يبلغ:')
        for key, value in caps.items():
            print(f'   📌 {key}: {value}')

awareness = AwarenessSystem()
awareness.report_status()
